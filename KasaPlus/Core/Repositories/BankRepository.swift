import Foundation
import SwiftData

struct BankDraft: Equatable, Sendable {
    var id: UUID?
    var name: String

    static let empty = BankDraft(id: nil, name: "")

    init(id: UUID? = nil, name: String) {
        self.id = id
        self.name = name
    }

    init(bank: Bank) {
        self.id = bank.id
        self.name = bank.name
    }

    var isValid: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}

@MainActor
protocol BankRepositoryProtocol: AnyObject {
    func fetchAll() throws -> [Bank]
    func bank(id: UUID) throws -> Bank?
    @discardableResult func save(_ draft: BankDraft) throws -> Bank
    func delete(id: UUID) throws
    func reorder(ids: [UUID]) throws
    func seedDefaultsIfNeeded() throws
    func transactionCount(bankID: UUID) throws -> Int

    // Senkronizasyon
    func pendingChanges() throws -> [Bank]
    func markSynced(ids: [UUID], at date: Date) throws
    func applyRemote(_ dto: BankDTO) throws
}

@MainActor
final class SwiftDataBankRepository: BankRepositoryProtocol {

    private let context: ModelContext
    private let userID: String

    init(context: ModelContext, userID: String) {
        self.context = context
        self.userID = userID
    }

    func fetchAll() throws -> [Bank] {
        let currentUserID = userID
        let descriptor = FetchDescriptor<Bank>(
            predicate: #Predicate { $0.userID == currentUserID && $0.isRemoved == false },
            sortBy: [SortDescriptor(\.sortOrder, order: .forward), SortDescriptor(\.name, order: .forward)]
        )
        return try context.fetch(descriptor)
    }

    func bank(id: UUID) throws -> Bank? {
        var descriptor = FetchDescriptor<Bank>(predicate: #Predicate { $0.id == id })
        descriptor.fetchLimit = 1
        return try context.fetch(descriptor).first
    }

    @discardableResult
    func save(_ draft: BankDraft) throws -> Bank {
        guard draft.isValid else { throw RepositoryError.invalidDraft }
        let name = draft.name.trimmingCharacters(in: .whitespacesAndNewlines)

        if let id = draft.id, let existing = try bank(id: id) {
            existing.name = name
            existing.updatedAt = .now
            try context.save()
            return existing
        }

        let orders = (try? fetchAll())?.map(\.sortOrder) ?? []
        let created = Bank(
            name: name,
            sortOrder: (orders.max() ?? -1) + 1,
            isDefault: false,
            userID: userID
        )
        context.insert(created)
        try context.save()
        return created
    }

    func delete(id: UUID) throws {
        guard let target = try bank(id: id) else { throw RepositoryError.notFound }
        target.isRemoved = true
        target.updatedAt = .now
        try context.save()
    }

    /// Kullanıcının sürükleyerek belirlediği yeni sırayı kalıcı hale getirir.
    func reorder(ids: [UUID]) throws {
        let now = Date()
        for (index, id) in ids.enumerated() {
            guard let target = try bank(id: id), target.sortOrder != index else { continue }
            target.sortOrder = index
            target.updatedAt = now
        }
        try context.save()
    }

    func seedDefaultsIfNeeded() throws {
        DefaultBanks.seedIfNeeded(context: context, userID: userID)
    }

    /// Bu bankaya bağlı, silinmemiş işlem sayısı — silme onayında uyarı için.
    func transactionCount(bankID: UUID) throws -> Int {
        // Model alanı `UUID?` olduğu için karşılaştırmayı da opsiyonel tipe sabitliyoruz.
        let target: UUID? = bankID
        let descriptor = FetchDescriptor<FinanceTransaction>(
            predicate: #Predicate { $0.bankID == target && $0.isRemoved == false }
        )
        return try context.fetchCount(descriptor)
    }

    // MARK: - Senkronizasyon

    func pendingChanges() throws -> [Bank] {
        let currentUserID = userID
        let descriptor = FetchDescriptor<Bank>(predicate: #Predicate { $0.userID == currentUserID })
        return try context.fetch(descriptor).filter { $0.hasPendingChanges }
    }

    func markSynced(ids: [UUID], at date: Date) throws {
        for id in ids {
            if let target = try bank(id: id) { target.syncedAt = date }
        }
        try context.save()
    }

    func applyRemote(_ dto: BankDTO) throws {
        if let existing = try bank(id: dto.id) {
            guard dto.updatedAt > existing.updatedAt else { return }
            existing.name = dto.name
            existing.sortOrder = dto.sortOrder
            existing.isDefault = dto.isDefault
            existing.updatedAt = dto.updatedAt
            existing.isRemoved = dto.isDeleted
            existing.syncedAt = .now
        } else {
            let created = Bank(
                id: dto.id,
                name: dto.name,
                sortOrder: dto.sortOrder,
                isDefault: dto.isDefault,
                userID: dto.userID,
                createdAt: dto.createdAt,
                updatedAt: dto.updatedAt,
                isRemoved: dto.isDeleted,
                syncedAt: .now
            )
            context.insert(created)
        }
        try context.save()
    }
}
