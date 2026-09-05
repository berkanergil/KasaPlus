import Foundation
import SwiftData

/// Genel gelir/gider takibine özel hazır kategoriler.
/// İlk açılışta (veya yeni bir kullanıcı ilk kez giriş yaptığında) bir kez eklenir.
enum DefaultCategories {

    struct Blueprint {
        let name: String
        let iconName: String
        let colorHex: String
        let type: TransactionType
    }

    static let blueprints: [Blueprint] = [
        // Giderler
        Blueprint(name: "Genel Gider", iconName: "ellipsis.circle.fill", colorHex: "#889096", type: .expense),
        // Gelirler
        Blueprint(name: "Genel Gelir", iconName: "plus.circle.fill", colorHex: "#0091FF", type: .income)
    ]

    /// Bu kullanıcı için hiç kategori yoksa hazır kategorileri ekler.
    /// Kullanıcı hazır kategorilerin tamamını silmişse tekrar eklemez —
    /// bu yüzden "silinmiş dahil" sayım yapılır.
    @discardableResult
    static func seedIfNeeded(context: ModelContext, userID: String) -> Bool {
        let descriptor = FetchDescriptor<Category>(
            predicate: #Predicate { $0.userID == userID }
        )
        let existingCount = (try? context.fetchCount(descriptor)) ?? 0
        guard existingCount == 0 else { return false }

        for (index, blueprint) in blueprints.enumerated() {
            let category = Category(
                name: blueprint.name,
                iconName: blueprint.iconName,
                colorHex: blueprint.colorHex,
                type: blueprint.type,
                isDefault: true,
                sortOrder: index,
                userID: userID
            )
            context.insert(category)
        }
        try? context.save()
        return true
    }
}
