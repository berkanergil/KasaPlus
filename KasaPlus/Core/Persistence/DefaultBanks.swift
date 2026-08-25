import Foundation
import SwiftData

/// Uygulamayla birlikte gelen hazır banka listesi.
/// Kullanıcı Ayarlar ▸ Banka Yönetimi'nden ekleyebilir, adını değiştirebilir,
/// sıralayabilir ve silebilir.
enum DefaultBanks {

    static let names: [String] = [
        "Ziraat Bankası",
        "İş Bankası",
        "Akbank",
        "TEB"
    ]

    /// Bu kullanıcı için hiç banka kaydı yoksa hazır listeyi ekler.
    /// Kullanıcı hepsini silmişse tekrar eklemez (silinmişler de sayılır).
    @discardableResult
    @MainActor
    static func seedIfNeeded(context: ModelContext, userID: String) -> Bool {
        let descriptor = FetchDescriptor<Bank>(
            predicate: #Predicate { $0.userID == userID }
        )
        let existingCount = (try? context.fetchCount(descriptor)) ?? 0
        guard existingCount == 0 else { return false }

        for (index, name) in names.enumerated() {
            context.insert(
                Bank(name: name, sortOrder: index, isDefault: true, userID: userID)
            )
        }
        try? context.save()
        return true
    }
}
