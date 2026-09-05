import Foundation

/// Ham işlem listesinden rapor verisi üreten saf hesaplama katmanı.
/// UI'dan ve veri kaynağından tamamen bağımsızdır — birim testi kolaydır.
struct ReportBuilder {

    let converter: CurrencyConverter
    var calendar: Calendar = .turkish

    // MARK: - Özet

    func summary(for transactions: [FinanceTransaction]) -> PeriodSummary {
        var result = PeriodSummary()
        for item in transactions {
            let (value, converted) = converter.convertForReporting(item.amount, from: item.currency)
            if !converted { result.hasUnconvertedAmounts = true }
            switch item.type {
            case .income: result.income += value
            case .expense: result.expense += value
            }
            result.transactionCount += 1
        }
        return result
    }

    // MARK: - Kategori dağılımı

    func breakdown(
        for transactions: [FinanceTransaction],
        type: TransactionType,
        categoryLookup: (UUID) -> Category?
    ) -> [CategoryBreakdownItem] {

        var totals: [UUID: (total: Double, count: Int)] = [:]
        for item in transactions where item.type == type {
            let (value, _) = converter.convertForReporting(item.amount, from: item.currency)
            let existing = totals[item.categoryID] ?? (0, 0)
            totals[item.categoryID] = (existing.total + value, existing.count + 1)
        }

        let grandTotal = totals.values.reduce(0) { $0 + $1.total }
        guard grandTotal > 0 else { return [] }

        return totals.map { categoryID, value in
            let category = categoryLookup(categoryID)
            return CategoryBreakdownItem(
                id: categoryID,
                name: category?.name ?? L10n.text("Silinmiş kategori"),
                iconName: category?.iconName ?? "questionmark.circle.fill",
                colorHex: category?.colorHex ?? "#889096",
                total: value.total,
                transactionCount: value.count,
                share: value.total / grandTotal
            )
        }
        .sorted { $0.total > $1.total }
    }

    // MARK: - Trend

    /// Haftalık ve aylık görünümde günlük, yıllık görünümde aylık kırılım üretir.
    /// Veri olmayan aralıklar da sıfır değerle döner ki grafik kesintisiz görünsün.
    func trend(
        for transactions: [FinanceTransaction],
        period: ReportPeriod,
        range: PeriodRange
    ) -> [TrendPoint] {

        let buckets = bucketDates(period: period, range: range)
        guard !buckets.isEmpty else { return [] }

        var income: [Date: Double] = [:]
        var expense: [Date: Double] = [:]

        for item in transactions {
            guard let bucket = bucketStart(for: item.date, period: period) else { continue }
            let (value, _) = converter.convertForReporting(item.amount, from: item.currency)
            switch item.type {
            case .income: income[bucket, default: 0] += value
            case .expense: expense[bucket, default: 0] += value
            }
        }

        return buckets.map { bucket in
            TrendPoint(
                id: bucket,
                date: bucket,
                label: label(for: bucket, period: period),
                income: income[bucket] ?? 0,
                expense: expense[bucket] ?? 0
            )
        }
    }

    private func bucketStart(for date: Date, period: ReportPeriod) -> Date? {
        switch period {
        case .week, .month:
            return calendar.startOfDay(for: date)
        case .year:
            return calendar.date(from: calendar.dateComponents([.year, .month], from: date))
        }
    }

    private func bucketDates(period: ReportPeriod, range: PeriodRange) -> [Date] {
        var result: [Date] = []
        switch period {
        case .week, .month:
            var cursor = calendar.startOfDay(for: range.start)
            while cursor <= range.end {
                result.append(cursor)
                guard let next = calendar.date(byAdding: .day, value: 1, to: cursor) else { break }
                cursor = next
            }
        case .year:
            var cursor = calendar.date(from: calendar.dateComponents([.year, .month], from: range.start)) ?? range.start
            while cursor <= range.end {
                result.append(cursor)
                guard let next = calendar.date(byAdding: .month, value: 1, to: cursor) else { break }
                cursor = next
            }
        }
        return result
    }

    private func label(for date: Date, period: ReportPeriod) -> String {
        switch period {
        case .week:
            return Formatters.weekdayShort.string(from: date)
        case .month:
            return Formatters.shortDay.string(from: date)
        case .year:
            return Formatters.monthShort.string(from: date)
        }
    }

    // MARK: - Gruplama (işlem listesi için)

    /// İşlemleri gün başlangıcına göre gruplar; en yeni gün önce gelir.
    func groupByDay(_ transactions: [FinanceTransaction]) -> [(day: Date, items: [FinanceTransaction])] {
        let grouped = Dictionary(grouping: transactions) { calendar.startOfDay(for: $0.date) }
        return grouped
            .map { (day: $0.key, items: $0.value.sorted { $0.createdAt > $1.createdAt }) }
            .sorted { $0.day > $1.day }
    }

    /// Bir günün net toplamı (ana para biriminde) — gün başlığında gösterilir.
    func dayNet(_ items: [FinanceTransaction]) -> Double {
        items.reduce(0) { partial, item in
            let (value, _) = converter.convertForReporting(item.amount, from: item.currency)
            return partial + value * item.type.signMultiplier
        }
    }
}
