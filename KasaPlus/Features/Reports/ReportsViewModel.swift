import Foundation
import Observation

@MainActor
@Observable
final class ReportsViewModel {

    var period: ReportPeriod = .month
    var periodOffset: Int = 0
    /// Kategori dağılımında hangi tür gösterilsin?
    var breakdownType: TransactionType = .expense
    var filter = TransactionFilter()

    private(set) var summary = PeriodSummary()
    private(set) var breakdown: [CategoryBreakdownItem] = []
    private(set) var trend: [TrendPoint] = []
    private(set) var comparison: PeriodComparison?

    @ObservationIgnored private let session: AppSession
    @ObservationIgnored private var converter: CurrencyConverter

    init(session: AppSession, converter: CurrencyConverter) {
        self.session = session
        self.converter = converter
    }

    var range: PeriodRange { PeriodRange.make(period: period, offset: periodOffset) }

    var comparisonLabel: String {
        switch period {
        case .week: return "Geçen hafta"
        case .month: return "Geçen ay"
        case .year: return "Geçen yıl"
        }
    }

    var trendGranularityLabel: String {
        switch period {
        case .week: return "Günlük kırılım"
        case .month: return "Günlük kırılım"
        case .year: return "Aylık kırılım"
        }
    }

    func updateConverter(_ converter: CurrencyConverter) {
        self.converter = converter
    }

    func load() {
        let builder = ReportBuilder(converter: converter)
        let currentRange = range

        var currentFilter = filter
        currentFilter.dateRange = currentRange.start ... currentRange.end
        let items = session.fetchTransactions(currentFilter)

        summary = builder.summary(for: items)
        trend = builder.trend(for: items, period: period, range: currentRange)
        breakdown = builder.breakdown(
            for: items,
            type: breakdownType,
            categoryLookup: { [session] in session.category(id: $0) }
        )

        let previousRange = PeriodRange.make(period: period, offset: periodOffset - 1)
        var previousFilter = filter
        previousFilter.dateRange = previousRange.start ... previousRange.end
        let previousItems = session.fetchTransactions(previousFilter)

        comparison = PeriodComparison(
            current: summary,
            previous: builder.summary(for: previousItems),
            currentTitle: currentRange.title,
            previousTitle: previousRange.title
        )
    }

    func resetFilter() {
        filter.reset()
        load()
    }

    var breakdownTotal: Double {
        breakdown.reduce(0) { $0 + $1.total }
    }

    var hasData: Bool { !summary.isEmpty }
}
