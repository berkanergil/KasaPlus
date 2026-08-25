import Foundation
import Observation

/// İşlem listesi ekranının durumu (MVVM — View yalnızca bu nesneyi okur).
@MainActor
@Observable
final class TransactionListViewModel {

    private(set) var groups: [(day: Date, items: [FinanceTransaction])] = []
    private(set) var summary = PeriodSummary()
    private(set) var isLoading = false

    var filter = TransactionFilter()
    var period: ReportPeriod = .month
    var periodOffset: Int = 0
    /// Dönem sınırlaması olmadan tüm kayıtları göster.
    var showsAllTime = false

    @ObservationIgnored private let session: AppSession
    @ObservationIgnored private var converter: CurrencyConverter

    init(session: AppSession, converter: CurrencyConverter) {
        self.session = session
        self.converter = converter
    }

    var range: PeriodRange {
        PeriodRange.make(period: period, offset: periodOffset)
    }

    var rangeTitle: String {
        showsAllTime ? "Tüm zamanlar" : range.title
    }

    func updateConverter(_ converter: CurrencyConverter) {
        self.converter = converter
    }

    func load() {
        isLoading = true
        defer { isLoading = false }

        var effectiveFilter = filter
        effectiveFilter.dateRange = showsAllTime ? nil : range.start ... range.end

        let items = session.fetchTransactions(effectiveFilter)
        let builder = ReportBuilder(converter: converter)
        groups = builder.groupByDay(items)
        summary = builder.summary(for: items)
    }

    func dayNet(_ items: [FinanceTransaction]) -> Double {
        ReportBuilder(converter: converter).dayNet(items)
    }

    func category(for transaction: FinanceTransaction) -> Category? {
        session.category(id: transaction.categoryID)
    }

    func delete(_ transaction: FinanceTransaction) {
        session.deleteTransaction(id: transaction.id)
        load()
    }

    func resetFilter() {
        filter.reset()
        load()
    }

    var hasResults: Bool { !groups.isEmpty }
}
