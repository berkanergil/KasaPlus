import SwiftUI
import Charts

struct DashboardView: View {

    let onQuickAdd: (TransactionType) -> Void
    let onShowPlannedPayments: () -> Void

    @Environment(AppSession.self) private var session
    @Environment(AppSettings.self) private var settings
    @Environment(ExchangeRateService.self) private var exchangeRates

    @State private var viewModel: DashboardViewModel?
    @State private var editorMode: TransactionEditorView.Mode?
    @State private var paidConfirmation: PlannedPayment?

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
            .navigationTitle("Özet")
            .refreshable {
                await exchangeRates.refresh()
                await session.syncService.syncIfPossible()
                viewModel?.load()
            }
        }
        .task { prepare() }
        .onChange(of: session.dataVersion) { _, _ in viewModel?.load() }
        .onChange(of: settings.mainCurrency) { _, _ in refreshConverter() }
        .onChange(of: exchangeRates.snapshot) { _, _ in refreshConverter() }
        .sheet(item: $editorMode) { mode in
            TransactionEditorView(mode: mode)
        }
        .confirmationDialog(
            "Gidere eklensin mi?",
            isPresented: Binding(
                get: { paidConfirmation != nil },
                set: { if !$0 { paidConfirmation = nil } }
            ),
            titleVisibility: .visible
        ) {
            Button("Ödedim, gidere ekle") {
                if let paidConfirmation { session.markPlannedPaymentPaid(id: paidConfirmation.id) }
                paidConfirmation = nil
            }
            Button("Vazgeç", role: .cancel) { paidConfirmation = nil }
        } message: {
            if let paidConfirmation {
                Text("\(paidConfirmation.title) — \(Formatters.money(paidConfirmation.amount, currency: paidConfirmation.currency)) tutarında bir gider kaydı oluşturulacak.")
            }
        }
    }

    // MARK: - Yaklaşan planlı ödemeler

    @ViewBuilder
    private func upcomingPaymentsCard() -> some View {
        let upcoming = Array(session.upcomingPlannedPayments(within: 7).prefix(4))
        if !upcoming.isEmpty {
            CardContainer {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Label("Yaklaşan Ödemeler", systemImage: "calendar.badge.clock")
                            .font(.subheadline.weight(.semibold))
                        Spacer()
                        Button("Tümü") { onShowPlannedPayments() }
                            .font(.caption.weight(.semibold))
                    }

                    ForEach(Array(upcoming.enumerated()), id: \.element.id) { index, payment in
                        HStack(spacing: 12) {
                            CategoryIconBadge(
                                iconName: session.category(id: payment.categoryID)?.iconName ?? "calendar",
                                colorHex: session.category(id: payment.categoryID)?.colorHex ?? "#889096",
                                size: 32
                            )
                            VStack(alignment: .leading, spacing: 2) {
                                Text(payment.title)
                                    .font(.footnote.weight(.medium))
                                    .lineLimit(1)
                                Text(payment.dueDescription())
                                    .font(.caption2)
                                    .foregroundStyle(payment.isOverdue() ? AppTheme.expense : .secondary)
                            }
                            Spacer(minLength: 8)
                            VStack(alignment: .trailing, spacing: 4) {
                                Text(Formatters.money(payment.amount, currency: payment.currency))
                                    .font(.footnote.weight(.semibold))
                                    .lineLimit(1)
                                Button("Ödedim") { paidConfirmation = payment }
                                    .font(.caption2.weight(.semibold))
                                    .buttonStyle(.bordered)
                                    .controlSize(.mini)
                            }
                        }

                        if index < upcoming.count - 1 {
                            Divider().padding(.leading, 44)
                        }
                    }
                }
            }
        }
    }

    // MARK: - İçerik

    @ViewBuilder
    private func content(_ viewModel: DashboardViewModel) -> some View {
        @Bindable var viewModel = viewModel

        VStack(spacing: 16) {
            // Selamlama
            VStack(alignment: .leading, spacing: 2) {
                Text(viewModel.greeting)
                    .font(.title2.bold())
                if let name = session.user.displayName, !name.isEmpty {
                    Text(name)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            // Hızlı ekleme
            HStack(spacing: 12) {
                QuickAddButton(type: .income) { onQuickAdd(.income) }
                QuickAddButton(type: .expense) { onQuickAdd(.expense) }
            }

            // Dönem seçici
            CardContainer {
                PeriodNavigator(
                    period: $viewModel.period,
                    offset: $viewModel.periodOffset,
                    range: viewModel.range
                )
            }
            .onChange(of: viewModel.period) { _, _ in viewModel.load() }
            .onChange(of: viewModel.periodOffset) { _, _ in viewModel.load() }

            // Bakiye kartı
            balanceCard(viewModel)

            if viewModel.summary.hasUnconvertedAmounts {
                InlineNotice(
                    systemImage: "exclamationmark.triangle.fill",
                    message: L10n.text("Bazı işlemlerin kuru bulunamadı; tutarlar çevrilmeden toplandı. İnternet bağlantısı gelince kur güncellenecek.")
                )
            }

            // Yaklaşan planlı ödemeler
            upcomingPaymentsCard()

            // Trend
            if !viewModel.trend.isEmpty {
                trendCard(viewModel)
            }

            // Karşılaştırma
            if let comparison = viewModel.comparison {
                comparisonCard(comparison, label: viewModel.comparisonLabel)
            }

            // En çok harcanan kategoriler
            if !viewModel.topExpenseCategories.isEmpty {
                topCategoriesCard(viewModel)
            }

            // Son işlemler
            recentCard(viewModel)
        }
        .padding(16)
    }

    // MARK: - Kartlar

    private func balanceCard(_ viewModel: DashboardViewModel) -> some View {
        CardContainer {
            VStack(alignment: .leading, spacing: 14) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Net Bakiye")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(Formatters.money(viewModel.summary.net, currency: settings.mainCurrency, showsSign: true))
                        .font(.system(size: 32, weight: .bold, design: .rounded))
                        .foregroundStyle(viewModel.summary.net >= 0 ? AppTheme.income : AppTheme.expense)
                        .contentTransition(.numericText())
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                }

                Divider()

                HStack {
                    SummaryTile(
                        title: L10n.text("Toplam Gelir"),
                        amount: viewModel.summary.income,
                        currency: settings.mainCurrency,
                        tint: AppTheme.income,
                        systemImage: "arrow.down.circle.fill"
                    )
                    SummaryTile(
                        title: L10n.text("Toplam Gider"),
                        amount: viewModel.summary.expense,
                        currency: settings.mainCurrency,
                        tint: AppTheme.expense,
                        systemImage: "arrow.up.circle.fill"
                    )
                }

                Text("\(viewModel.summary.transactionCount) işlem")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
    }

    private func trendCard(_ viewModel: DashboardViewModel) -> some View {
        CardContainer {
            VStack(alignment: .leading, spacing: 10) {
                Text("Dönem Hareketi")
                    .font(.subheadline.weight(.semibold))

                Chart(viewModel.trend) { point in
                    LineMark(
                        x: .value("Tarih", point.date),
                        y: .value("Tutar", point.income),
                        series: .value("Seri", "Gelir")
                    )
                    .foregroundStyle(AppTheme.income)
                    .interpolationMethod(.monotone)
                    .lineStyle(StrokeStyle(lineWidth: 2))

                    LineMark(
                        x: .value("Tarih", point.date),
                        y: .value("Tutar", point.expense),
                        series: .value("Seri", "Gider")
                    )
                    .foregroundStyle(AppTheme.expense)
                    .interpolationMethod(.monotone)
                    .lineStyle(StrokeStyle(lineWidth: 2))
                }
                .chartLegend(.hidden)
                .chartYAxis {
                    AxisMarks(position: .leading) { value in
                        AxisGridLine()
                        AxisValueLabel {
                            if let amount = value.as(Double.self) {
                                Text(CompactNumber.text(amount))
                                    .font(.caption2)
                            }
                        }
                    }
                }
                .frame(height: 150)

                HStack(spacing: 16) {
                    LegendDot(color: AppTheme.income, title: L10n.text("Gelir"))
                    LegendDot(color: AppTheme.expense, title: L10n.text("Gider"))
                }
            }
        }
    }

    private func comparisonCard(_ comparison: PeriodComparison, label: String) -> some View {
        CardContainer {
            VStack(alignment: .leading, spacing: 12) {
                Text(label)
                    .font(.subheadline.weight(.semibold))

                ComparisonRow(
                    title: L10n.text("Gelir"),
                    change: comparison.incomeChange,
                    increaseIsPositive: true,
                    currentValue: comparison.current.income,
                    previousValue: comparison.previous.income,
                    currency: settings.mainCurrency
                )
                ComparisonRow(
                    title: L10n.text("Gider"),
                    change: comparison.expenseChange,
                    increaseIsPositive: false,
                    currentValue: comparison.current.expense,
                    previousValue: comparison.previous.expense,
                    currency: settings.mainCurrency
                )
                ComparisonRow(
                    title: L10n.text("Net"),
                    change: comparison.netChange,
                    increaseIsPositive: true,
                    currentValue: comparison.current.net,
                    previousValue: comparison.previous.net,
                    currency: settings.mainCurrency
                )
            }
        }
    }

    private func topCategoriesCard(_ viewModel: DashboardViewModel) -> some View {
        CardContainer {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("En Çok Harcama")
                        .font(.subheadline.weight(.semibold))
                    Spacer()
                    CategoryManagerButton()
                }

                ForEach(viewModel.topExpenseCategories) { item in
                    HStack(spacing: 12) {
                        CategoryIconBadge(iconName: item.iconName, colorHex: item.colorHex, size: 32)

                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text(item.name)
                                    .font(.footnote.weight(.medium))
                                    .lineLimit(1)
                                Spacer()
                                Text(Formatters.money(item.total, currency: settings.mainCurrency))
                                    .font(.footnote.weight(.semibold))
                            }
                            ProgressView(value: min(item.share, 1))
                                .tint(Color(hex: item.colorHex))
                                .scaleEffect(x: 1, y: 0.6, anchor: .center)
                        }
                    }
                }
            }
        }
    }

    private func recentCard(_ viewModel: DashboardViewModel) -> some View {
        CardContainer(padding: 12) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Son İşlemler")
                    .font(.subheadline.weight(.semibold))
                    .padding(.horizontal, 4)

                if viewModel.recentTransactions.isEmpty {
                    EmptyStateView(
                        systemImage: "tray",
                        title: L10n.text("Kayıt yok"),
                        message: L10n.text("Bu dönemde henüz işlem eklenmemiş."),
                        actionTitle: L10n.text("Gider ekle"),
                        action: { onQuickAdd(.expense) }
                    )
                } else {
                    ForEach(Array(viewModel.recentTransactions.enumerated()), id: \.element.id) { index, item in
                        Button {
                            editorMode = .edit(transaction: item)
                        } label: {
                            TransactionRowView(
                                transaction: item,
                                category: viewModel.category(for: item),
                                bankName: session.bankName(id: item.bankID),
                                converter: currentConverter
                            )
                            .padding(.horizontal, 4)
                        }
                        .buttonStyle(.plain)

                        if index < viewModel.recentTransactions.count - 1 {
                            Divider().padding(.leading, 54)
                        }
                    }
                }
            }
        }
    }

    // MARK: - Kurulum

    private var currentConverter: CurrencyConverter {
        CurrencyConverter(snapshot: exchangeRates.snapshot, mainCurrency: settings.mainCurrency)
    }

    private func prepare() {
        if viewModel == nil {
            let model = DashboardViewModel(session: session, converter: currentConverter)
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

// MARK: - Yardımcı görünümler

private struct QuickAddButton: View {
    let type: TransactionType
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: "plus.circle.fill")
                    .font(.title3)
                Text(type.title)
                    .font(.subheadline.weight(.semibold))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(type.tintColor.opacity(0.14), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .foregroundStyle(type.tintColor)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(type.title) ekle")
    }
}

private struct ComparisonRow: View {
    let title: String
    let change: Double?
    let increaseIsPositive: Bool
    let currentValue: Double
    let previousValue: Double
    let currency: Currency

    var body: some View {
        HStack {
            Text(title)
                .font(.footnote)
                .frame(width: 44, alignment: .leading)

            VStack(alignment: .leading, spacing: 1) {
                Text(Formatters.money(currentValue, currency: currency))
                    .font(.footnote.weight(.semibold))
                Text(L10n.format("Önce %@", Formatters.money(previousValue, currency: currency)))
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }

            Spacer()

            ChangeBadge(change: change, increaseIsPositive: increaseIsPositive)
        }
    }
}

struct LegendDot: View {
    let color: Color
    let title: String

    var body: some View {
        HStack(spacing: 5) {
            Circle()
                .fill(color)
                .frame(width: 8, height: 8)
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}

/// Grafik eksenlerinde "12,5 B" gibi kısa sayı gösterimi.
enum CompactNumber {
    static func text(_ value: Double) -> String {
        let absValue = abs(value)
        let formatter = NumberFormatter()
        formatter.locale = Formatters.locale
        formatter.maximumFractionDigits = absValue >= 10_000 ? 0 : 1
        formatter.minimumFractionDigits = 0

        switch absValue {
        case 1_000_000...:
            let scaled = value / 1_000_000
            return (formatter.string(from: NSNumber(value: scaled)) ?? "0") + " M"
        case 1_000...:
            let scaled = value / 1_000
            return (formatter.string(from: NSNumber(value: scaled)) ?? "0") + " B"
        default:
            return formatter.string(from: NSNumber(value: value)) ?? "0"
        }
    }
}
