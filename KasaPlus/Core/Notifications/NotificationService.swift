import Foundation
import Observation
import UserNotifications

/// Yerel bildirim izni ve planlanan ödeme hatırlatmalarının kurulumu.
///
/// Tüm bildirimler **yereldir** — sunucu veya push sertifikası gerekmez.
@MainActor
@Observable
final class NotificationService {

    private(set) var authorizationStatus: UNAuthorizationStatus = .notDetermined
    private(set) var scheduledCount: Int = 0
    /// Sıraya alınamayan (sistem sınırını aşan) ödeme sayısı.
    private(set) var skippedPaymentCount: Int = 0

    /// iOS bir uygulama için en fazla 64 bekleyen yerel bildirim tutar.
    /// Ödeme başına 3 hatırlatma kurduğumuz için en yakın 20 ödemeyi planlıyoruz.
    private static let maxScheduledPayments = 20

    @ObservationIgnored private let center = UNUserNotificationCenter.current()

    var isAuthorized: Bool {
        authorizationStatus == .authorized || authorizationStatus == .provisional
    }

    var statusDescription: String {
        switch authorizationStatus {
        case .authorized, .provisional: return L10n.text("İzin verildi")
        case .denied: return L10n.text("Kapalı — Ayarlar ▸ Bildirimler")
        case .notDetermined: return L10n.text("Henüz sorulmadı")
        case .ephemeral: return L10n.text("Geçici izin")
        @unknown default: return L10n.text("Bilinmiyor")
        }
    }

    // MARK: - İzin

    func refreshAuthorizationStatus() async {
        let settings = await center.notificationSettings()
        authorizationStatus = settings.authorizationStatus
    }

    /// İlk planlanan ödeme kaydedilirken veya ayarlardan çağrılır.
    @discardableResult
    func requestAuthorizationIfNeeded() async -> Bool {
        await refreshAuthorizationStatus()
        if isAuthorized { return true }
        guard authorizationStatus == .notDetermined else { return false }

        do {
            let granted = try await center.requestAuthorization(options: [.alert, .sound, .badge])
            await refreshAuthorizationStatus()
            return granted
        } catch {
            await refreshAuthorizationStatus()
            return false
        }
    }

    // MARK: - Planlanan ödeme hatırlatmaları

    /// Verilen planlanan ödemeler için tüm hatırlatmaları **baştan** kurar.
    /// Önce mevcut "planned-payment-" istekleri temizlenir; böylece silinen veya
    /// ertelenen kayıtların eski bildirimleri kalmaz.
    func reschedule(payments: [PlannedPayment], categoryName: @escaping (UUID) -> String?) async {
        await refreshAuthorizationStatus()

        let pending = await center.pendingNotificationRequests()
        let staleIdentifiers = pending
            .map(\.identifier)
            .filter { $0.hasPrefix(PlannedPaymentNotifications.requestPrefix) }
        if !staleIdentifiers.isEmpty {
            center.removePendingNotificationRequests(withIdentifiers: staleIdentifiers)
        }

        guard isAuthorized else {
            scheduledCount = 0
            skippedPaymentCount = 0
            return
        }

        var scheduled = 0
        let now = Date()
        let calendar = Calendar.turkish

        // Vadesi en yakın olanlar önce; sistem sınırı nedeniyle listeyi kırpıyoruz.
        let eligible = payments
            .filter { $0.status == .pending && $0.reminderEnabled && !$0.isRemoved }
            .sorted { $0.dueDate < $1.dueDate }
        skippedPaymentCount = max(0, eligible.count - Self.maxScheduledPayments)
        let scheduling = Array(eligible.prefix(Self.maxScheduledPayments))

        for payment in scheduling {
            let name = categoryName(payment.categoryID)

            for stage in PlannedPaymentNotifications.Stage.allCases {
                guard let fireDate = calendar.date(
                    byAdding: .day,
                    value: -stage.daysBefore,
                    to: payment.dueDate
                ), fireDate > now else { continue }

                let content = UNMutableNotificationContent()
                content.title = PlannedPaymentNotifications.title(for: stage, payment: payment)
                content.body = PlannedPaymentNotifications.body(for: stage, payment: payment, categoryName: name)
                content.sound = .default
                content.userInfo = [PlannedPaymentNotifications.paymentIDKey: payment.id.uuidString]
                // Aksiyon butonları yalnızca vade günü bildiriminde gösterilir.
                if stage == .due {
                    content.categoryIdentifier = PlannedPaymentNotifications.categoryIdentifier
                }

                let components = calendar.dateComponents(
                    [.year, .month, .day, .hour, .minute],
                    from: fireDate
                )
                let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)

                let request = UNNotificationRequest(
                    identifier: PlannedPaymentNotifications.requestIdentifier(paymentID: payment.id, stage: stage),
                    content: content,
                    trigger: trigger
                )

                do {
                    try await center.add(request)
                    scheduled += 1
                } catch {
                    #if DEBUG
                    print("[Notifications] Bildirim kurulamadı: \(error.localizedDescription)")
                    #endif
                }
            }
        }

        scheduledCount = scheduled
    }

    /// Tek bir ödemenin bildirimlerini kaldırır (ödendi / silindi).
    func cancel(paymentID: UUID) {
        center.removePendingNotificationRequests(
            withIdentifiers: PlannedPaymentNotifications.allRequestIdentifiers(paymentID: paymentID)
        )
        center.removeDeliveredNotifications(
            withIdentifiers: PlannedPaymentNotifications.allRequestIdentifiers(paymentID: paymentID)
        )
    }

    func cancelAll() {
        center.removeAllPendingNotificationRequests()
        scheduledCount = 0
        skippedPaymentCount = 0
    }
}
