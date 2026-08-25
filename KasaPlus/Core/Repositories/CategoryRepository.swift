import Foundation
import SwiftData

/// Kategori düzenleme ekranından repository'ye taşınan veri.
struct CategoryDraft: Equatable, Sendable {
    var id: UUID?
    var name: String
    var iconName: String
    var colorHex: String
    var type: TransactionType

    static func empty(type: TransactionType = .expense) -> CategoryDraft {
        CategoryDraft(
            id: nil,
            name: "",
            iconName: CategoryPalette.icons.first ?? "tag.fill",
            colorHex: CategoryPalette.colors.first ?? "#0091FF",
            type: type
        )
    }

    init(id: UUID? = nil, name: String, iconName: String, colorHex: String, type: TransactionType) {
        self.id = id
        self.name = name
        self.iconName = iconName
        self.colorHex = colorHex
        self.type = type
    }

    init(category: Category) {
        self.id = category.id
        self.name = category.name
        self.iconName = category.iconName
        self.colorHex = category.colorHex
        self.type = category.type
    }

    var isValid: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}

@MainActor
protocol CategoryRepositoryProtocol: AnyObject {
    func fetchAll() throws -> [Category]
    func fetch(type: TransactionType) throws -> [Category]
    func category(id: UUID) throws -> Category?
    @discardableResult func save(_ draft: CategoryDraft) throws -> Category
    func delete(id: UUID) throws
    func reorder(ids: [UUID]) throws
    func seedDefaultsIfNeeded() throws
    func transactionCount(categoryID: UUID) throws -> Int

    // Senkronizasyon
    func pendingChanges() throws -> [Category]
    func markSynced(ids: [UUID], at date: Date) throws
    func applyRemote(_ dto: CategoryDTO) throws
}

@MainActor
final class SwiftDataCategoryRepository: CategoryRepositoryProtocol {
    private let context: ModelContext
    private let userID: String

    init(context: ModelContext, userID: String) {
        self.context = context
        self.userID = userID
    }

    func fetchAll() throws -> [Category] {
        let currentUserID = userID
        let descriptor = FetchDescriptor<Category>(
            predicate: #Predicate { $0.userID == currentUserID && $0.isRemoved == false },
            sortBy: [SortDescriptor(\.sortOrder, order: .forward), SortDescriptor(\.name, order: .forward)]
        )
        return try context.fetch(descriptor)
    }

    func fetch(type: TransactionType) throws -> [Category] {
        try fetchAll().filter { $0.type == type }
    }

    func category(id: UUID) throws -> Category? {
        var descriptor = FetchDescriptor<Category>(predicate: #Predicate { $0.id == id })
        descriptor.fetchLimit = 1
        return try context.fetch(descriptor).first
    }

    @discardableResult
    func save(_ draft: CategoryDraft) throws -> Category {
        guard draft.isValid else { throw RepositoryError.invalidDraft }
        let name = draft.name.trimmingCharacters(in: .whitespacesAndNewlines)

        if let id = draft.id, let existing = try category(id: id) {
            existing.name = name
            existing.iconName = draft.iconName
            existing.colorHex = draft.colorHex
            existing.type = draft.type
            existing.updatedAt = .now
            try context.save()
            return existing
        }

        let existingOrders = (try? fetchAll())?.map(\.sortOrder) ?? []
        let nextOrder = (existingOrders.max() ?? 0) + 1
        let created = Category(
            name: name,
            iconName: draft.iconName,
            colorHex: draft.colorHex,
            type: draft.type,
            isDefault: false,
            sortOrder: nextOrder,
            userID: userID
        )
        context.insert(created)
        try context.save()
        return created
    }

    func delete(id: UUID) throws {
        guard let target = try category(id: id) else { throw RepositoryError.notFound }
        target.isRemoved = true
        target.updatedAt = .now
        try context.save()
    }

    /// Kullanıcının sürükleyerek belirlediği yeni sırayı kalıcı hale getirir.
    /// `ids`, ilgili türün kategorilerinin yeni sırasıdır.
    func reorder(ids: [UUID]) throws {
        let now = Date()
        for (index, id) in ids.enumerated() {
            guard let target = try category(id: id), target.sortOrder != index else { continue }
            target.sortOrder = index
            target.updatedAt = now
        }
        try context.save()
    }

    func seedDefaultsIfNeeded() throws {
        DefaultCategories.seedIfNeeded(context: context, userID: userID)
    }

    /// Bu kategoriye bağlı, silinmemiş işlem sayısı — silme onayında uyarı için.
    func transactionCount(categoryID: UUID) throws -> Int {
        let descriptor = FetchDescriptor<FinanceTransaction>(
            predicate: #Predicate { $0.categoryID == categoryID && $0.isRemoved == false }
        )
        return try context.fetchCount(descriptor)
    }

    // MARK: - Senkronizasyon

    func pendingChanges() throws -> [Category] {
        let currentUserID = userID
        let descriptor = FetchDescriptor<Category>(predicate: #Predicate { $0.userID == currentUserID })
        return try context.fetch(descriptor).filter { $0.hasPendingChanges }
    }

    func markSynced(ids: [UUID], at date: Date) throws {
        for id in ids {
            if let category = try category(id: id) {
                category.syncedAt = date
            }
        }
        try context.save()
    }

    func applyRemote(_ dto: CategoryDTO) throws {
        if let existing = try category(id: dto.id) {
            guard dto.updatedAt > existing.updatedAt else { return }
            existing.name = dto.name
            existing.iconName = dto.iconName
            existing.colorHex = dto.colorHex
            existing.typeRaw = dto.type
            existing.isDefault = dto.isDefault
            existing.sortOrder = dto.sortOrder
            existing.updatedAt = dto.updatedAt
            existing.isRemoved = dto.isDeleted
            existing.syncedAt = .now
        } else {
            let created = Category(
                id: dto.id,
                name: dto.name,
                iconName: dto.iconName,
                colorHex: dto.colorHex,
                type: TransactionType(rawValue: dto.type) ?? .expense,
                isDefault: dto.isDefault,
                sortOrder: dto.sortOrder,
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
