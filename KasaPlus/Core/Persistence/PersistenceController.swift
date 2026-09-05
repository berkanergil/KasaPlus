import Foundation
import SwiftData

/// SwiftData `ModelContainer`'ını üreten tek nokta.
/// Uygulama offline-first çalıştığı için yerel depo her zaman zorunludur.
enum PersistenceController {
    static let schema = Schema([
        FinanceTransaction.self,
        Category.self,
        Bank.self,
        PlannedPayment.self
    ])

    /// Uygulamanın gerçek (diskte kalıcı) konteyneri.
    static func makeContainer() -> ModelContainer {
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false, cloudKitDatabase: .automatic)
        do {
            return try ModelContainer(for: schema, configurations: [configuration])
        } catch {
            // Diskteki depo açılamazsa (ör. bozuk dosya) uygulamanın hiç açılmaması
            // yerine bu oturumu bellek içi depoyla sürdürüyoruz. Kullanıcıya
            // Ayarlar ▸ Bulut Yedekleme üzerinden veri geri yükleme yolu açık kalır.
            assertionFailure("Kalıcı ModelContainer oluşturulamadı: \(error)")
            let fallback = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
            do {
                return try ModelContainer(for: schema, configurations: [fallback])
            } catch {
                // Bellek içi depo da kurulamıyorsa şema tanımı bozuktur; bu bir
                // geliştirme hatasıdır ve sessizce devam etmek doğru olmaz.
                fatalError("SwiftData şeması geçersiz: \(error)")
            }
        }
    }

    /// Önizleme ve testler için bellek içi konteyner.
    @MainActor
    static func makePreviewContainer() -> ModelContainer {
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        do {
            let container = try ModelContainer(for: schema, configurations: [configuration])
            DefaultCategories.seedIfNeeded(context: container.mainContext, userID: "preview-user")
            return container
        } catch {
            fatalError("Önizleme konteyneri oluşturulamadı: \(error)")
        }
    }
}
