import Foundation
import Observation

@MainActor
@Observable
final class DashboardViewModel {

    var period: ReportPeriod = .month
    var periodOffset: Int = 0

    private(set) var summary = PeriodSummary()
    private(set) var comparison: PeriodComparison?
    private(set) var recentTransactions: [FinanceTransaction] = []
    private(set) var topExpenseCategories: [CategoryBreakdownItem] = []
    private(set) var trend: [TrendPoint] = []

    @ObservationIgnored private let session: AppSession
    @ObservationIgnored private var converter: CurrencyConverter

    init(session: AppSession, converter: CurrencyConverter) {
        self.session = session
        self.converter = converter
    }

    var range: PeriodRange { PeriodRange.make(period: period, offset: periodOffset) }

    var greeting: String {
        let hour = Calendar.turkish.component(.hour, from: .now)
        switch hour {
        case 5..<12: return "Günaydın"
        case 12..<18: return "İyi günler"
        default: return "İyi akşamlar"
        }
    }

    func updateConverter(_ converter: CurrencyConverter) {
        self.converter = converter
    }

    func load() {
        let builder = ReportBuilder(converter: converter)
        let currentRange = range

        var filter = TransactionFilter()
        filter.dateRange = currentRange.start ... currentRange.end
        let items = session.fetchTransactions(filter)

        summary = builder.summary(for: items)
        trend = builder.trend(for: items, period: period, range: currentRange)
        topExpenseCategories = Array(
            builder.breakdown(for: items, type: .expense, categoryLookup: { [session] in session.category(id: $0) })
                .prefix(4)
        )
        recentTransactions = Array(items.sorted { $0.date > $1.date }.prefix(5))

        // Önceki dönemle karşılaştırma
        let previousRange = PeriodRange.make(period: period, offset: periodOffset - 1)
        var previousFilter = TransactionFilter()
        previousFilter.dateRange = previousRange.start ... previousRange.end
        let previousItems = session.fetchTransactions(previousFilter)

        comparison = PeriodComparison(
            current: summary,
            previous: builder.summary(for: previousItems),
            currentTitle: currentRange.title,
            previousTitle: previousRange.title
        )
    }

    func category(for transaction: FinanceTransaction) -> Category? {
        session.category(id: transaction.categoryID)
    }

    var comparisonLabel: String {
        switch period {
        case .week: return "Geçen haftaya göre"
        case .month: return "Geçen aya göre"
        case .year: return "Geçen yıla göre"
        }
    }
}
