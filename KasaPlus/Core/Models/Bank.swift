import Foundation
import SwiftData

/// Kredi kartı, banka kartı, havale ve çek işlemlerinin bağlandığı banka.
/// Kullanıcı ayarlardan yeni banka ekleyebilir, adını değiştirebilir,
/// sırasını düzenleyebilir ve silebilir.
@Model
final class Bank {
    @Attribute(.unique) var id: UUID

    var name: String
    /// Listelerdeki sıra (kullanıcı sürükleyerek değiştirebilir)
    var sortOrder: Int
    /// Uygulamayla birlikte gelen hazır banka mı?
    var isDefault: Bool

    // MARK: - Çoklu kullanıcı / senkronizasyon alanları

    var userID: String
    var createdAt: Date
    var updatedAt: Date
    var isRemoved: Bool
    var syncedAt: Date?

    init(
        id: UUID = UUID(),
        name: String,
        sortOrder: Int = 0,
        isDefault: Bool = false,
        userID: String,
        createdAt: Date = .now,
        updatedAt: Date = .now,
        isRemoved: Bool = false,
        syncedAt: Date? = nil
    ) {
        self.id = id
        self.name = name
        self.sortOrder = sortOrder
        self.isDefault = isDefault
        self.userID = userID
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.isRemoved = isRemoved
        self.syncedAt = syncedAt
    }
}

extension Bank {
    var hasPendingChanges: Bool {
        guard let syncedAt else { return true }
        return updatedAt > syncedAt
    }

    /// Liste ve rozetlerde kullanılan iki harfli kısaltma (örn. "Ziraat Bankası" → "ZB").
    var initials: String {
        let words = name
            .split(separator: " ")
            .filter { $0.count > 1 }
            .prefix(2)
        let letters = words.compactMap { $0.first }.map(String.init).joined()
        return letters.isEmpty ? String(name.prefix(2)).uppercased() : letters.uppercased()
    }
}
