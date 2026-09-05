import SwiftUI
import Charts

struct ReportsView: View {

    @Environment(AppSession.self) private var session
    @Environment(AppSettings.self) private var settings
    @Environment(ExchangeRateService.self) private var exchangeRates

    @State private var viewModel: ReportsViewModel?
    @State private var selectedSliceID: UUID?

    var body: some View {
        NavigationStack {
            ScrollView {
                if let viewModel {
                    content(viewModel)
                } else {
                    ProgressView().padding(.top, 60)
                }
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Raporlar")
        }
        .task { prepare() }
        .onChange(of: session.dataVersion) { _, _ in viewModel?.load() }
        .onChange(of: settings.mainCurrency) { _, _ in refreshConverter() }
        .onChange(of: exchangeRates.snapshot) { _, _ in refreshConverter() }
    }

    @ViewBuilder
    private func content(_ viewModel: ReportsViewModel) -> some View {
        @Bindable var viewModel = viewModel

        VStack(spacing: 16) {
            CardContainer {
                PeriodNavigator(
                    period: $viewModel.period,
                    offset: $viewModel.periodOffset,
                    range: viewModel.range
                )
            }
            .onChange(of: viewModel.period) { _, _ in viewModel.load() }
            .onChange(of: viewModel.periodOffset) { _, _ in viewModel.load() }

            if !viewModel.hasData {
                CardContainer {
                    EmptyStateView(
                        systemImage: "chart.pie",
                        title: L10n.text("Bu dönemde veri yok"),
                        message: L10n.text("Rapor görebilmek için bu döneme ait gelir veya gider kaydı ekleyin.")
                    )
                }
            } else {
                summaryCard(viewModel)
                breakdownCard(viewModel)
                trendCard(viewModel)
                if let comparison = viewModel.comparison {
                    comparisonCard(comparison, label: viewModel.comparisonLabel)
                }
            }
        }
        .padding(16)
    }

    // MARK: - Özet

    private func summaryCard(_ viewModel: ReportsViewModel) -> some View {
        CardContainer {
            VStack(alignment: .leading, spacing: 12) {
                Text(viewModel.range.title)
                    .font(.subheadline.weight(.semibold))

                HStack {
                    SummaryTile(
                        title: L10n.text("Gelir"),
                        amount: viewModel.summary.income,
                        currency: settings.mainCurrency,
                        tint: AppTheme.income
                    )
                    SummaryTile(
                        title: L10n.text("Gider"),
                        amount: viewModel.summary.expense,
                        currency: settings.mainCurrency,
                        tint: AppTheme.expense
                    )
                    SummaryTile(
                        title: L10n.text("Net"),
                        amount: viewModel.summary.net,
                        currency: settings.mainCurrency,
                        tint: viewModel.summary.net >= 0 ? AppTheme.income : AppTheme.expense,
                        showsSign: true
                    )
                }

                if let ratio = viewModel.summary.expenseRatio {
                    Text("Gelirin \(Formatters.percent(ratio * 100))'i gidere gitti.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    // MARK: - Kategori dağılımı (donut)

    private func breakdownCard(_ viewModel: ReportsViewModel) -> some View {
        @Bindable var viewModel = viewModel

        return CardContainer {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    Text("Kategori Dağılımı")
                        .font(.subheadline.weight(.semibold))
                    Spacer()
                    CategoryManagerButton()
                }

                Picker("Tür", selection: $viewModel.breakdownType) {
                    ForEach(TransactionType.allCases) { type in
                        Text(type.title).tag(type)
                    }
                }
                .pickerStyle(.segmented)
                .onChange(of: viewModel.breakdownType) { _, _ in
                    selectedSliceID = nil
                    viewModel.load()
                }

                if viewModel.breakdown.isEmpty {
                    Text("Bu dönemde \(viewModel.breakdownType.title.lowercased()) kaydı yok.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.vertical, 24)
                } else {
                    ZStack {
                        Chart(viewModel.breakdown) { item in
                            SectorMark(
                                angle: .value("Tutar", item.total),
                                innerRadius: .ratio(0.62),
                                angularInset: 1.5
                            )
                            .cornerRadius(4)
                            .foregroundStyle(Color(hex: item.colorHex))
                            .opacity(selectedSliceID == nil || selectedSliceID == item.id ? 1 : 0.35)
                        }
                        .frame(height: 200)

                        VStack(spacing: 2) {
                            if let selected = viewModel.breakdown.first(where: { $0.id == selectedSliceID }) {
                                Text(selected.name)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                                Text(Formatters.money(selected.total, currency: settings.mainCurrency))
                                    .font(.headline)
                                Text(Formatters.percent(selected.share * 100))
                                    .font(.caption2)
                                    .foregroundStyle(.tertiary)
                            } else {
                                Text("Toplam")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                Text(Formatters.money(viewModel.breakdownTotal, currency: settings.mainCurrency))
                                    .font(.headline)
                            }
                        }
                        .frame(maxWidth: 110)
                        .multilineTextAlignment(.center)
                    }

                    VStack(spacing: 10) {
                        ForEach(viewModel.breakdown) { item in
                            Button {
                                selectedSliceID = (selectedSliceID == item.id) ? nil : item.id
                            } label: {
                                HStack(spacing: 10) {
                                    Circle()
                                        .fill(Color(hex: item.colorHex))
                                        .frame(width: 10, height: 10)
                                    Text(item.name)
                                        .font(.footnote)
                                        .lineLimit(1)
                                        .foregroundStyle(.primary)
                                    Spacer(minLength: 8)
                                    Text(Formatters.percent(item.share * 100))
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                    Text(Formatters.money(item.total, currency: settings.mainCurrency))
                                        .font(.footnote.weight(.semibold))
                                        .foregroundStyle(.primary)
                                }
                                .padding(.vertical, 2)
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
        }
    }

    // MARK: - Trend

    private func trendCard(_ viewModel: ReportsViewModel) -> some View {
        CardContainer {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text("Trend")
                        .font(.subheadline.weight(.semibold))
                    Spacer()
                    Text(viewModel.trendGranularityLabel)
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }

                Chart {
                    ForEach(viewModel.trend) { point in
                        BarMark(
                            x: .value("Dönem", point.date, unit: viewModel.period == .year ? .month : .day),
                            y: .value("Tutar", point.income)
                        )
                        .position(by: .value("Tür", "Gelir"))
                        .foregroundStyle(AppTheme.income)
                        .cornerRadius(3)

                        BarMark(
                            x: .value("Dönem", point.date, unit: viewModel.period == .year ? .month : .day),
                            y: .value("Tutar", point.expense)
                        )
                        .position(by: .value("Tür", "Gider"))
                        .foregroundStyle(AppTheme.expense)
                        .cornerRadius(3)
                    }
                }
                .chartLegend(.hidden)
                .chartYAxis {
                    AxisMarks(position: .leading) { value in
                        AxisGridLine()
                        AxisValueLabel {
                            if let amount = value.as(Double.self) {
                                Text(CompactNumber.text(amount)).font(.caption2)
                            }
                        }
                    }
                }
                .chartXAxis {
                    AxisMarks(values: .automatic(desiredCount: 6)) { value in
                        AxisGridLine()
                        AxisValueLabel {
                            if let date = value.as(Date.self) {
                                Text(xAxisLabel(for: date, period: viewModel.period))
                                    .font(.caption2)
                            }
                        }
                    }
                }
                .frame(height: 200)

                HStack(spacing: 16) {
                    LegendDot(color: AppTheme.income, title: L10n.text("Gelir"))
                    LegendDot(color: AppTheme.expense, title: L10n.text("Gider"))
                }
            }
        }
    }

    private func xAxisLabel(for date: Date, period: ReportPeriod) -> String {
        switch period {
        case .week: return Formatters.weekdayShort.string(from: date)
        case .month: return Formatters.shortDay.string(from: date)
        case .year: return Formatters.monthShort.string(from: date)
        }
    }

    // MARK: - Karşılaştırma

    private func comparisonCard(_ comparison: PeriodComparison, label: String) -> some View {
        CardContainer {
            VStack(alignment: .leading, spacing: 12) {
                Text("Dönem Karşılaştırması")
                    .font(.subheadline.weight(.semibold))

                HStack {
                    Text(comparison.previousTitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Image(systemName: "arrow.right")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                    Text(comparison.currentTitle)
                        .font(.caption.weight(.semibold))
                }

                Divider()

                comparisonRow(L10n.text("Gelir"), comparison.previous.income, comparison.current.income, comparison.incomeChange, true)
                comparisonRow(L10n.text("Gider"), comparison.previous.expense, comparison.current.expense, comparison.expenseChange, false)
                comparisonRow("Net", comparison.previous.net, comparison.current.net, comparison.netChange, true)
            }
        }
    }

    private func comparisonRow(
        _ title: String,
        _ previous: Double,
        _ current: Double,
        _ change: Double?,
        _ increaseIsPositive: Bool
    ) -> some View {
        HStack {
            Text(title)
                .font(.footnote)
                .frame(width: 44, alignment: .leading)
            Text(Formatters.money(previous, currency: settings.mainCurrency))
                .font(.caption)
                .foregroundStyle(.tertiary)
            Spacer()
            Text(Formatters.money(current, currency: settings.mainCurrency))
                .font(.footnote.weight(.semibold))
            ChangeBadge(change: change, increaseIsPositive: increaseIsPositive)
        }
    }

    // MARK: - Kurulum

    private var currentConverter: CurrencyConverter {
        CurrencyConverter(snapshot: exchangeRates.snapshot, mainCurrency: settings.mainCurrency)
    }

    private func prepare() {
        if viewModel == nil {
            let model = ReportsViewModel(session: session, converter: currentConverter)
            model.load()
            viewModel = model
        } else {
            refreshConverter()
        }
    }

    private func refreshConverter() {
        viewModel?.updateConverter(currentConverter)
        viewModel?.load()
    }
}
