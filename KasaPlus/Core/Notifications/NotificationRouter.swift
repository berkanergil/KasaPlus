import Foundation
import Observation
import SwiftData
import UserNotifications

/// Bildirim aksiyonlarının veri katmanına erişebilmesi için paylaşılan konteyner.
///
/// `KasaPlusApp.init` içinde, herhangi bir bildirim işlenmeden önce atanır.
/// Aktör izolasyonu dışında tutulur çünkü uygulama arka planda (arayüz kurulmadan)
/// bir bildirim aksiyonu için başlatılabilir.
enum NotificationContainer {
    nonisolated(unsafe) static var shared: ModelContainer?
}

/// Bildirimden gelen aksiyonları uygulamaya taşır.
///
/// - "Ödedim": uygulama arka planda başlatılsa bile doğrudan veriye yazar
///   (ödeme gidere dönüşür).
/// - "Ertele" veya bildirime dokunma: uygulama öne gelir ve ilgili ekran/sayfa açılır;
///   erteleme için tarih seçme yaprağı gösterilir.
@MainActor
@Observable
final class NotificationRouter {

    static let shared = NotificationRouter()

    /// Erteleme yaprağının açılacağı ödeme.
    var postponeRequestID: UUID?
    /// Planlanan ödemeler sekmesine geçilmesi istendi mi?
    var shouldOpenPlannedPayments = false
    /// Arka planda yapılan işlemin kullanıcıya gösterilecek sonucu.
    var lastActionMessage: String?

    /// Veri değiştiğinde ekranların tazelenmesi için `AppSession` tarafından atanır.
    @ObservationIgnored var onDataChanged: (() -> Void)?

    private init() {}

    // MARK: - Bildirim yanıtı

    func handle(response: UNNotificationResponse) {
        let userInfo = response.notification.request.content.userInfo
        guard
            let idString = userInfo[PlannedPaymentNotifications.paymentIDKey] as? String,
            let paymentID = UUID(uuidString: idString)
        else { return }

        switch response.actionIdentifier {
        case PlannedPaymentNotifications.markPaidActionIdentifier:
            markPaid(paymentID: paymentID)

        case PlannedPaymentNotifications.postponeActionIdentifier:
            shouldOpenPlannedPayments = true
            postponeRequestID = paymentID

        case UNNotificationDefaultActionIdentifier:
            shouldOpenPlannedPayments = true

        default:
            break
        }
    }

    /// Bildirimdeki "Ödedim" butonu. Uygulama çalışmıyor olabilir; bu yüzden
    /// `AppSession`'a değil doğrudan veri katmanına yazıyoruz.
    private func markPaid(paymentID: UUID) {
        guard let container = NotificationContainer.shared else { return }
        let context = container.mainContext

        var descriptor = FetchDescriptor<PlannedPayment>(predicate: #Predicate { $0.id == paymentID })
        descriptor.fetchLimit = 1
        guard let payment = try? context.fetch(descriptor).first else { return }

        let repository = SwiftDataPlannedPaymentRepository(context: context, userID: payment.userID)
        do {
            _ = try repository.markPaid(id: paymentID, on: .now)
            NotificationService().cancel(paymentID: paymentID)
            lastActionMessage = L10n.format("%@ ödendi olarak işaretlendi ve giderlere eklendi.", "\"\(payment.title)\"")
            onDataChanged?()
        } catch {
            lastActionMessage = L10n.format("İşlem tamamlanamadı: %@", error.localizedDescription)
        }
    }

    func clearPostponeRequest() {
        postponeRequestID = nil
    }

    func clearMessage() {
        lastActionMessage = nil
    }
}
