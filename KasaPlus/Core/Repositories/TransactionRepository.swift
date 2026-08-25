import Foundation
import SwiftData

// MARK: - Filtre & taslak modelleri

/// İşlem listesinde ve raporlarda kullanılan filtre kriterleri.
struct TransactionFilter: Equatable, Sendable {
    var dateRange: ClosedRange<Date>?
    var types: Set<TransactionType> = []
    var categoryIDs: Set<UUID> = []
    var paymentMethods: Set<PaymentMethod> = []
    var bankIDs: Set<UUID> = []
    var searchText: String = ""

    static let all = TransactionFilter()

    var isActive: Bool {
        !types.isEmpty || !categoryIDs.isEmpty || !paymentMethods.isEmpty
        || !bankIDs.isEmpty || !searchText.isEmpty
    }

    var activeCriteriaCount: Int {
        var count = 0
        if !types.isEmpty { count += 1 }
        if !categoryIDs.isEmpty { count += 1 }
        if !paymentMethods.isEmpty { count += 1 }
        if !bankIDs.isEmpty { count += 1 }
        if !searchText.isEmpty { count += 1 }
        return count
    }

    mutating func reset() {
        types = []
        categoryIDs = []
        paymentMethods = []
        bankIDs = []
        searchText = ""
    }
}

/// Ekranlardan repository'ye taşınan düzenlenebilir işlem verisi.
/// `id` nil ise yeni kayıt, dolu ise güncelleme yapılır.
struct TransactionDraft: Equatable, Sendable {
    var id: UUID?
    var amount: Double
    var date: Date
    var type: TransactionType
    var currency: Currency
    var paymentMethod: PaymentMethod
    var categoryID: UUID?
    /// Nakit dışı ödeme yöntemlerinde bağlı banka
    var bankID: UUID?
    var note: String

    static func empty(type: TransactionType = .expense, currency: Currency = .TRY) -> TransactionDraft {
        TransactionDraft(
            id: nil,
            amount: 0,
            date: .now,
            type: type,
            currency: currency,
            paymentMethod: .cash,
            categoryID: nil,
            bankID: nil,
            note: ""
        )
    }

    init(
        id: UUID? = nil,
        amount: Double,
        date: Date,
        type: TransactionType,
        currency: Currency,
        paymentMethod: PaymentMethod,
        categoryID: UUID?,
        bankID: UUID? = nil,
        note: String
    ) {
        self.id = id
        self.amount = amount
        self.date = date
        self.type = type
        self.currency = currency
        self.paymentMethod = paymentMethod
        self.categoryID = categoryID
        self.bankID = bankID
        self.note = note
    }

    init(transaction: FinanceTransaction) {
        self.id = transaction.id
        self.amount = transaction.amount
        self.date = transaction.date
        self.type = transaction.type
        self.currency = transaction.currency
        self.paymentMethod = transaction.paymentMethod
        self.categoryID = transaction.categoryID
        self.bankID = transaction.bankID
        self.note = transaction.note ?? ""
    }

    var isValid: Bool { amount > 0 && categoryID != nil }
}

enum RepositoryError: LocalizedError {
    case invalidDraft
    case notFound

    var errorDescription: String? {
        switch self {
        case .invalidDraft: return "Kayıt eksik. Tutar ve kategori zorunludur."
        case .notFound: return "Kayıt bulunamadı."
        }
    }
}

// MARK: - Protokol

/// İşlem verisine erişim soyutlaması. Üst katmanlar (ViewModel'ler) yalnızca bu
/// protokolü bilir; veri kaynağı değişse bile etkilenmezler (PRD 7.2).
@MainActor
protocol TransactionRepositoryProtocol: AnyObject {
    func fetch(_ filter: TransactionFilter) throws -> [FinanceTransaction]
    func transaction(id: UUID) throws -> FinanceTransaction?
    @discardableResult func save(_ draft: TransactionDraft) throws -> FinanceTransaction
    func delete(id: UUID) throws
    func earliestTransactionDate() throws -> Date?

    // Senkronizasyon
    func pendingChanges() throws -> [FinanceTransaction]
    func markSynced(ids: [UUID], at date: Date) throws
    func applyRemote(_ dto: TransactionDTO) throws
    func purgeSyncedTombstones(olderThan date: Date) throws
}

// MARK: - SwiftData implementasyonu

@MainActor
final class SwiftDataTransactionRepository: TransactionRepositoryProtocol {
    private let context: ModelContext
    private let userID: String

    init(context: ModelContext, userID: String) {
        self.context = context
        self.userID = userID
    }

    func fetch(_ filter: TransactionFilter) throws -> [FinanceTransaction] {
        // Tarih aralığı sorguya, diğer kriterler bellekte uygulanır:
        // kayıt sayısı bir eczane için küçüktür ve #Predicate'in sınırlarına takılmayız.
        let currentUserID = userID
        var descriptor: FetchDescriptor<FinanceTransaction>

        if let range = filter.dateRange {
            let lower = range.lowerBound
            let upper = range.upperBound
            descriptor = FetchDescriptor<FinanceTransaction>(
                predicate: #Predicate { item in
                    item.userID == currentUserID &&
                    item.isRemoved == false &&
                    item.date >= lower &&
                    item.date <= upper
                },
                sortBy: [SortDescriptor(\.date, order: .reverse), SortDescriptor(\.createdAt, order: .reverse)]
            )
        } else {
            descriptor = FetchDescriptor<FinanceTransaction>(
                predicate: #Predicate { item in
                    item.userID == currentUserID && item.isRemoved == false
                },
                sortBy: [SortDescriptor(\.date, order: .reverse), SortDescriptor(\.createdAt, order: .reverse)]
            )
        }

        let results = try context.fetch(descriptor)
        return results.filter { matches($0, filter: filter) }
    }

    private func matches(_ item: FinanceTransaction, filter: TransactionFilter) -> Bool {
        if !filter.types.isEmpty, !filter.types.contains(item.type) { return false }
        if !filter.categoryIDs.isEmpty, !filter.categoryIDs.contains(item.categoryID) { return false }
        if !filter.paymentMethods.isEmpty, !filter.paymentMethods.contains(item.paymentMethod) { return false }
        if !filter.bankIDs.isEmpty {
            guard let bankID = item.bankID, filter.bankIDs.contains(bankID) else { return false }
        }
        if !filter.searchText.isEmpty {
            let needle = filter.searchText.lowercased()
            let haystack = (item.note ?? "").lowercased()
            if !haystack.contains(needle) { return false }
        }
        return true
    }

    func transaction(id: UUID) throws -> FinanceTransaction? {
        var descriptor = FetchDescriptor<FinanceTransaction>(predicate: #Predicate { $0.id == id })
        descriptor.fetchLimit = 1
        return try context.fetch(descriptor).first
    }

    @discardableResult
    func save(_ draft: TransactionDraft) throws -> FinanceTransaction {
        guard draft.isValid, let categoryID = draft.categoryID else {
            throw RepositoryError.invalidDraft
        }

        let trimmedNote = draft.note.trimmingCharacters(in: .whitespacesAndNewlines)
        // Nakit işlemlerde banka bilgisi tutulmaz.
        let bankID = draft.paymentMethod.requiresBank ? draft.bankID : nil

        if let id = draft.id, let existing = try transaction(id: id) {
            existing.amount = draft.amount
            existing.date = draft.date
            existing.type = draft.type
            existing.currency = draft.currency
            existing.paymentMethod = draft.paymentMethod
            existing.categoryID = categoryID
            existing.bankID = bankID
            existing.note = trimmedNote.isEmpty ? nil : trimmedNote
            existing.updatedAt = .now
            try context.save()
            return existing
        }

        let item = FinanceTransaction(
            amount: draft.amount,
            date: draft.date,
            type: draft.type,
            currency: draft.currency,
            paymentMethod: draft.paymentMethod,
            categoryID: categoryID,
            bankID: bankID,
            note: trimmedNote.isEmpty ? nil : trimmedNote,
            userID: userID
        )
        context.insert(item)
        try context.save()
        return item
    }

    /// Yumuşak silme: kayıt mezar taşı olarak işaretlenir ki silme işlemi
    /// buluta ve diğer cihazlara da yansıyabilsin.
    func delete(id: UUID) throws {
        guard let item = try transaction(id: id) else { throw RepositoryError.notFound }
        item.isRemoved = true
        item.updatedAt = .now
        try context.save()
    }

    func earliestTransactionDate() throws -> Date? {
        let currentUserID = userID
        var descriptor = FetchDescriptor<FinanceTransaction>(
            predicate: #Predicate { $0.userID == currentUserID && $0.isRemoved == false },
            sortBy: [SortDescriptor(\.date, order: .forward)]
        )
        descriptor.fetchLimit = 1
        return try context.fetch(descriptor).first?.date
    }

    // MARK: - Senkronizasyon

    func pendingChanges() throws -> [FinanceTransaction] {
        let currentUserID = userID
        let descriptor = FetchDescriptor<FinanceTransaction>(
            predicate: #Predicate { $0.userID == currentUserID }
        )
        return try context.fetch(descriptor).filter { $0.hasPendingChanges }
    }

    func markSynced(ids: [UUID], at date: Date) throws {
        for id in ids {
            if let item = try transaction(id: id) {
                item.syncedAt = date
            }
        }
        try context.save()
    }

    /// Uzak taraftan gelen kaydı yerele uygular. Çakışmada `updatedAt` büyük olan kazanır.
    func applyRemote(_ dto: TransactionDTO) throws {
        if let existing = try transaction(id: dto.id) {
            guard dto.updatedAt > existing.updatedAt else { return }
            existing.amount = dto.amount
            existing.date = dto.date
            existing.typeRaw = dto.type
            existing.currencyRaw = dto.currency
            existing.paymentMethodRaw = dto.paymentMethod
            existing.categoryID = dto.categoryID
            existing.bankID = dto.bankID
            existing.note = dto.note
            existing.updatedAt = dto.updatedAt
            existing.isRemoved = dto.isDeleted
            existing.syncedAt = .now
        } else {
            let item = FinanceTransaction(
                id: dto.id,
                amount: dto.amount,
                date: dto.date,
                type: TransactionType(rawValue: dto.type) ?? .expense,
                currency: Currency.from(rawValue: dto.currency),
                paymentMethod: PaymentMethod.from(rawValue: dto.paymentMethod),
                categoryID: dto.categoryID,
                bankID: dto.bankID,
                note: dto.note,
                userID: dto.userID,
                createdAt: dto.createdAt,
                updatedAt: dto.updatedAt,
                isRemoved: dto.isDeleted,
                syncedAt: .now
            )
            context.insert(item)
        }
        try context.save()
    }

    /// Buluta gönderilmiş eski mezar taşlarını yerelden temizler.
    func purgeSyncedTombstones(olderThan date: Date) throws {
        let currentUserID = userID
        let descriptor = FetchDescriptor<FinanceTransaction>(
            predicate: #Predicate { $0.userID == currentUserID && $0.isRemoved == true }
        )
        let stale = try context.fetch(descriptor).filter { item in
            guard let syncedAt = item.syncedAt else { return false }
            return syncedAt < date && item.updatedAt <= syncedAt
        }
        for item in stale { context.delete(item) }
        if !stale.isEmpty { try context.save() }
    }
}
