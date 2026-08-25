import Foundation
import SwiftData

/// Eczane iş koluna özel hazır kategoriler.
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
        Blueprint(name: "Stok / İlaç Alımı", iconName: "pills.fill", colorHex: "#E5484D", type: .expense),
        Blueprint(name: "Kira", iconName: "house.fill", colorHex: "#F76808", type: .expense),
        Blueprint(name: "Fatura", iconName: "bolt.fill", colorHex: "#FFB224", type: .expense),
        Blueprint(name: "Personel Maaşı", iconName: "person.2.fill", colorHex: "#8E4EC6", type: .expense),
        Blueprint(name: "SGK / Vergi", iconName: "doc.text.fill", colorHex: "#A18072", type: .expense),
        Blueprint(name: "Tedarikçi Ödemesi", iconName: "shippingbox.fill", colorHex: "#12A594", type: .expense),
        Blueprint(name: "Diğer Gider", iconName: "ellipsis.circle.fill", colorHex: "#889096", type: .expense),
        // Gelirler
        Blueprint(name: "Reçeteli Satış", iconName: "cross.case.fill", colorHex: "#30A46C", type: .income),
        Blueprint(name: "Reçetesiz Satış", iconName: "bag.fill", colorHex: "#46A758", type: .income),
        Blueprint(name: "Diğer Gelir", iconName: "plus.circle.fill", colorHex: "#0091FF", type: .income)
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
