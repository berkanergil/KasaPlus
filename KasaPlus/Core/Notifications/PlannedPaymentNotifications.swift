import Foundation
import UserNotifications

/// Planlanan ödeme bildirimlerinin kimlik, kategori ve aksiyon tanımları.
///
/// Üç bildirim kurulur (PRD ek isteği):
///  • Vadeden **1 hafta** önce  — bilgilendirme
///  • Vadeden **1 gün** önce    — hatırlatma
///  • **Vade günü**             — "Gidere eklensin mi?" + `Ödedim` / `Ertele` butonları
enum PlannedPaymentNotifications {

    // MARK: - Kimlikler

    static let categoryIdentifier = "PLANNED_PAYMENT"
    static let markPaidActionIdentifier = "PLANNED_PAYMENT_MARK_PAID"
    static let postponeActionIdentifier = "PLANNED_PAYMENT_POSTPONE"

    static let paymentIDKey = "plannedPaymentID"

    /// Bildirim isteği kimliği öneki — yeniden kurarken toplu silmek için.
    static let requestPrefix = "planned-payment-"

    enum Stage: String, CaseIterable {
        case week
        case day
        case due

        /// Vadeden kaç gün önce tetiklenecek?
        var daysBefore: Int {
            switch self {
            case .week: return 7
            case .day: return 1
            case .due: return 0
            }
        }
    }

    static func requestIdentifier(paymentID: UUID, stage: Stage) -> String {
        "\(requestPrefix)\(paymentID.uuidString)-\(stage.rawValue)"
    }

    static func allRequestIdentifiers(paymentID: UUID) -> [String] {
        Stage.allCases.map { requestIdentifier(paymentID: paymentID, stage: $0) }
    }

    // MARK: - Bildirim kategorisi (aksiyon butonları)

    static var category: UNNotificationCategory {
        let markPaid = UNNotificationAction(
            identifier: markPaidActionIdentifier,
            title: "Ödedim",
            options: []
        )
        // Erteleme için tarih seçtirmemiz gerekiyor → uygulamayı öne getir.
        let postpone = UNNotificationAction(
            identifier: postponeActionIdentifier,
            title: "Ertele",
            options: [.foreground]
        )

        return UNNotificationCategory(
            identifier: categoryIdentifier,
            actions: [markPaid, postpone],
            intentIdentifiers: [],
            options: [.customDismissAction]
        )
    }

    // MARK: - Metinler

    static func title(for stage: Stage, payment: PlannedPayment) -> String {
        switch stage {
        case .week: return "Yaklaşan ödeme: \(payment.title)"
        case .day: return "Yarın ödeme günü: \(payment.title)"
        case .due: return "Bugün ödeme günü: \(payment.title)"
        }
    }

    static func body(for stage: Stage, payment: PlannedPayment, categoryName: String?) -> String {
        let amount = Formatters.money(payment.amount, currency: payment.currency)
        let dateText = Formatters.dayHeader.string(from: payment.dueDate)
        let categorySuffix = categoryName.map { " · \($0)" } ?? ""

        switch stage {
        case .week:
            return "\(amount)\(categorySuffix) — vade \(dateText)."
        case .day:
            return "\(amount)\(categorySuffix) — ödeme yarın yapılmalı."
        case .due:
            return "\(amount)\(categorySuffix) — bu tutar giderlere eklensin mi?"
        }
    }
}
