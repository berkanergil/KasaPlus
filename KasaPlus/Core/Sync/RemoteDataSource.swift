import Foundation

/// Uzak (bulut) veri kaynağı soyutlaması.
///
/// Uygulama offline-first çalışır: bu protokolün hiçbir implementasyonu olmasa da
/// tüm özellikler yereldeki SwiftData deposu üzerinden tam olarak çalışır.
/// Firebase SDK projeye eklendiğinde `FirestoreRemoteDataSource` otomatik devreye girer.
protocol RemoteDataSource: Sendable {
    /// Bulut yapılandırması hazır mı? (`GoogleService-Info.plist` + Firebase SDK)
    var isConfigured: Bool { get }
    /// Ayarlar ekranında gösterilen kısa durum açıklaması.
    var statusDescription: String { get }

    func fetchChanges(since date: Date?, userID: String) async throws -> RemoteSnapshot
    func push(
        transactions: [TransactionDTO],
        categories: [CategoryDTO],
        banks: [BankDTO],
        plannedPayments: [PlannedPaymentDTO],
        userID: String
    ) async throws
}

/// Firebase yokken kullanılan boş implementasyon.
/// Hiçbir şey yapmaz, hata da fırlatmaz — uygulama sorunsuz çalışmaya devam eder.
struct DisabledRemoteDataSource: RemoteDataSource {
    var isConfigured: Bool { false }
    var statusDescription: String { L10n.text("Bulut yedekleme yapılandırılmadı") }

    func fetchChanges(since date: Date?, userID: String) async throws -> RemoteSnapshot {
        RemoteSnapshot()
    }

    func push(
        transactions: [TransactionDTO],
        categories: [CategoryDTO],
        banks: [BankDTO],
        plannedPayments: [PlannedPaymentDTO],
        userID: String
    ) async throws {
        // Yerel veri zaten kalıcı; yapılacak bir şey yok.
    }
}

/// Ortama göre doğru uzak veri kaynağını üretir.
///
/// Firebase SDK Swift Package olarak eklendiğinde `canImport(FirebaseFirestore)`
/// doğru olur ve gerçek Firestore kaynağı kullanılır. Tek satır bile değiştirmeniz gerekmez.
enum RemoteDataSourceFactory {
    static func make() -> RemoteDataSource {
        return DisabledRemoteDataSource()
    }
}

enum SyncError: LocalizedError {
    case notConfigured
    case notAuthenticated
    case remote(String)

    var errorDescription: String? {
        switch self {
        case .notConfigured:
            return L10n.text("Bulut yedekleme henüz yapılandırılmadı. Kurulum adımları için README dosyasına bakın.")
        case .notAuthenticated:
            return L10n.text("Yedekleme için oturum açmanız gerekiyor.")
        case .remote(let message):
            return message
        }
    }
}
