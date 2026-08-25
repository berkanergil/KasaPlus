import Foundation
import SwiftData

/// Gelir veya gider kategorisi. Hazır (varsayılan) ve kullanıcı tanımlı kategoriler
/// aynı modeli kullanır; `isDefault` yalnızca kaynağını belirtir.
@Model
final class Category {
    @Attribute(.unique) var id: UUID

    var name: String
    /// SF Symbols adı
    var iconName: String
    /// "#RRGGBB" biçiminde renk
    var colorHex: String
    /// `TransactionType.rawValue` — kategorinin hangi işlem türüne ait olduğu
    var typeRaw: String

    /// Uygulamayla birlikte gelen hazır kategori mi?
    var isDefault: Bool
    /// Listelerde sıralama önceliği
    var sortOrder: Int

    // MARK: - Çoklu kullanıcı / senkronizasyon alanları

    var userID: String
    var createdAt: Date
    var updatedAt: Date
    var isRemoved: Bool
    var syncedAt: Date?

    init(
        id: UUID = UUID(),
        name: String,
        iconName: String,
        colorHex: String,
        type: TransactionType,
        isDefault: Bool = false,
        sortOrder: Int = 0,
        userID: String,
        createdAt: Date = .now,
        updatedAt: Date = .now,
        isRemoved: Bool = false,
        syncedAt: Date? = nil
    ) {
        self.id = id
        self.name = name
        self.iconName = iconName
        self.colorHex = colorHex
        self.typeRaw = type.rawValue
        self.isDefault = isDefault
        self.sortOrder = sortOrder
        self.userID = userID
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.isRemoved = isRemoved
        self.syncedAt = syncedAt
    }
}

extension Category {
    var type: TransactionType {
        get { TransactionType(rawValue: typeRaw) ?? .expense }
        set { typeRaw = newValue.rawValue }
    }

    var hasPendingChanges: Bool {
        guard let syncedAt else { return true }
        return updatedAt > syncedAt
    }
}
