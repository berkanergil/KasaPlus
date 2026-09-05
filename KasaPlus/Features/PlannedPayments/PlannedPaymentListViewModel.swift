import Foundation
import Observation

@MainActor
@Observable
final class PlannedPaymentListViewModel {

    /// Listedeki bölümler.
    struct Section: Identifiable {
        let id: String
        let title: String
        let systemImage: String
        let items: [PlannedPayment]
    }

    private(set) var sections: [Section] = []
    private(set) var pendingTotal: Double = 0
    private(set) var overdueCount: Int = 0
    private(set) var hasUnconvertedAmounts = false

    /// Ödenenler de gösterilsin mi?
    var showsPaid = false

    @ObservationIgnored private let session: AppSession
    @ObservationIgnored private var converter: CurrencyConverter

    init(session: AppSession, converter: CurrencyConverter) {
        self.session = session
        self.converter = converter
    }

    func updateConverter(_ converter: CurrencyConverter) {
        self.converter = converter
    }

    func load() {
        let all = session.fetchPlannedPayments()
        let pending = all.filter { $0.status == .pending }

        let overdue = pending.filter { $0.daysRemaining() < 0 }
            .sorted { $0.dueDate < $1.dueDate }
        let thisWeek = pending.filter { (0...7).contains($0.daysRemaining()) }
            .sorted { $0.dueDate < $1.dueDate }
        let later = pending.filter { $0.daysRemaining() > 7 }
            .sorted { $0.dueDate < $1.dueDate }
        let paid = all.filter { $0.status == .paid }
            .sorted { ($0.paidAt ?? $0.dueDate) > ($1.paidAt ?? $1.dueDate) }

        var result: [Section] = []
        if !overdue.isEmpty {
            result.append(Section(id: "overdue", title: L10n.text("Gecikmiş"), systemImage: "exclamationmark.triangle.fill", items: overdue))
        }
        if !thisWeek.isEmpty {
            result.append(Section(id: "week", title: L10n.text("Bu hafta"), systemImage: "calendar.badge.clock", items: thisWeek))
        }
        if !later.isEmpty {
            result.append(Section(id: "later", title: L10n.text("İleri tarihli"), systemImage: "calendar", items: later))
        }
        if showsPaid, !paid.isEmpty {
            result.append(Section(id: "paid", title: L10n.text("Ödenenler"), systemImage: "checkmark.circle.fill", items: paid))
        }

        sections = result
        overdueCount = overdue.count

        var total: Double = 0
        var missingRate = false
        for payment in pending {
            let (value, converted) = converter.convertForReporting(payment.amount, from: payment.currency)
            if !converted { missingRate = true }
            total += value
        }
        pendingTotal = total
        hasUnconvertedAmounts = missingRate
    }

    var isEmpty: Bool { sections.isEmpty }

    func category(for payment: PlannedPayment) -> Category? {
        session.category(id: payment.categoryID)
    }

    func bankName(for payment: PlannedPayment) -> String? {
        session.bankName(id: payment.bankID)
    }

    func secondaryAmountText(for payment: PlannedPayment) -> String? {
        guard payment.currency != converter.mainCurrency,
              let converted = converter.convert(payment.amount, from: payment.currency) else { return nil }
        return "≈ " + Formatters.money(converted, currency: converter.mainCurrency)
    }
}
