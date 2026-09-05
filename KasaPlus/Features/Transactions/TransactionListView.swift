import SwiftUI

struct TransactionListView: View {

    @Environment(AppSession.self) private var session
    @Environment(AppSettings.self) private var settings
    @Environment(ExchangeRateService.self) private var exchangeRates

    @State private var viewModel: TransactionListViewModel?
    @State private var editorMode: TransactionEditorView.Mode?
    @State private var pendingDeletion: FinanceTransaction?
    @State private var isFilterPresented = false

    var body: some View {
        NavigationStack {
            Group {
                if let viewModel {
                    content(viewModel)
                } else {
                    ProgressView()
                }
            }
            .navigationTitle("İşlemler")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        isFilterPresented = true
                    } label: {
                        Image(systemName: viewModel?.filter.isActive == true
                              ? "line.3.horizontal.decrease.circle.fill"
                              : "line.3.horizontal.decrease.circle")
                    }
                    .accessibilityLabel("Filtrele")
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Button {
                            editorMode = .create(type: .income)
                        } label: {
                            Label("Gelir Ekle", systemImage: TransactionType.income.systemImage)
                        }
                        Button {
                            editorMode = .create(type: .expense)
                        } label: {
                            Label("Gider Ekle", systemImage: TransactionType.expense.systemImage)
                        }
                    } label: {
                        Image(systemName: "plus")
                    }
                    .accessibilityLabel("Yeni işlem")
                }
            }
        }
        .task { prepare() }
        .onChange(of: session.dataVersion) { _, _ in viewModel?.load() }
        .onChange(of: settings.mainCurrency) { _, _ in refreshConverter() }
        .onChange(of: exchangeRates.snapshot) { _, _ in refreshConverter() }
        .sheet(item: $editorMode) { mode in
            TransactionEditorView(mode: mode)
        }
        .sheet(isPresented: $isFilterPresented) {
            if let viewModel {
                TransactionFilterView(viewModel: viewModel)
            }
        }
        .confirmationDialog(
            "Bu işlemi silmek istediğinize emin misiniz?",
            isPresented: Binding(
                get: { pendingDeletion != nil },
                set: { if !$0 { pendingDeletion = nil } }
            ),
            titleVisibility: .visible
        ) {
            Button("Sil", role: .destructive) {
                if let pendingDeletion {
                    viewModel?.delete(pendingDeletion)
                }
                pendingDeletion = nil
            }
            Button("Vazgeç", role: .cancel) { pendingDeletion = nil }
        } message: {
            Text("Bu işlem geri alınamaz.")
        }
    }

    // MARK: - İçerik

    @ViewBuilder
    private func content(_ viewModel: TransactionListViewModel) -> some View {
        @Bindable var viewModel = viewModel

        List {
            Section {
                VStack(spacing: 14) {
                    if !viewModel.showsAllTime {
                        PeriodNavigator(
                            period: $viewModel.period,
                            offset: $viewModel.periodOffset,
                            range: viewModel.range
                        )
                    }

                    HStack(spacing: 12) {
                        SummaryTile(
                            title: L10n.text("Gelir"),
                            amount: viewModel.summary.income,
                            currency: settings.mainCurrency,
                            tint: AppTheme.income,
                            systemImage: "arrow.down"
                        )
                        Divider().frame(height: 32)
                        SummaryTile(
                            title: L10n.text("Gider"),
                            amount: viewModel.summary.expense,
                            currency: settings.mainCurrency,
                            tint: AppTheme.expense,
                            systemImage: "arrow.up"
                        )
                        Divider().frame(height: 32)
                        SummaryTile(
                            title: L10n.text("Net"),
                            amount: viewModel.summary.net,
                            currency: settings.mainCurrency,
                            tint: viewModel.summary.net >= 0 ? AppTheme.income : AppTheme.expense,
                            showsSign: true
                        )
                    }

                    Toggle("Tüm zamanları göster", isOn: $viewModel.showsAllTime)
                        .font(.footnote)
                        .onChange(of: viewModel.showsAllTime) { _, _ in viewModel.load() }

                    if viewModel.filter.isActive {
                        HStack {
                            Label("\(viewModel.filter.activeCriteriaCount) filtre etkin", systemImage: "line.3.horizontal.decrease")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Spacer()
                            Button("Temizle") { viewModel.resetFilter() }
                                .font(.caption.weight(.semibold))
                        }
                    }
                }
                .padding(.vertical, 4)
            }

            if viewModel.hasResults {
                ForEach(viewModel.groups, id: \.day) { group in
                    Section {
                        ForEach(group.items) { item in
                            Button {
                                editorMode = .edit(transaction: item)
                            } label: {
                                TransactionRowView(
                                    transaction: item,
                                    category: viewModel.category(for: item),
                                    bankName: session.bankName(id: item.bankID),
                                    converter: currentConverter
                                )
                            }
                            .buttonStyle(.plain)
                            .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                Button(role: .destructive) {
                                    pendingDeletion = item
                                } label: {
                                    Label("Sil", systemImage: "trash")
                                }
                                Button {
                                    editorMode = .edit(transaction: item)
                                } label: {
                                    Label("Düzenle", systemImage: "pencil")
                                }
                                .tint(AppTheme.accent)
                            }
                        }
                    } header: {
                        HStack {
                            Text(Formatters.relativeDayTitle(for: group.day))
                            Spacer()
                            let net = viewModel.dayNet(group.items)
                            Text(Formatters.money(net, currency: settings.mainCurrency, showsSign: true))
                                .foregroundStyle(net >= 0 ? AppTheme.income : AppTheme.expense)
                        }
                        .font(.caption)
                        .textCase(nil)
                    }
                }
            } else {
                Section {
                    EmptyStateView(
                        systemImage: viewModel.filter.isActive ? "line.3.horizontal.decrease.circle" : "tray",
                        title: viewModel.filter.isActive ? L10n.text("Sonuç bulunamadı") : L10n.text("Henüz kayıt yok"),
                        message: viewModel.filter.isActive
                            ? L10n.text("Filtreleri değiştirerek tekrar deneyin.")
                            : L10n.text("Bu dönemde kayıtlı bir gelir veya gider yok. Sağ üstteki + ile ekleyebilirsiniz."),
                        actionTitle: viewModel.filter.isActive ? L10n.text("Filtreleri temizle") : L10n.text("Gider ekle"),
                        action: {
                            if viewModel.filter.isActive {
                                viewModel.resetFilter()
                            } else {
                                editorMode = .create(type: .expense)
                            }
                        }
                    )
                    .listRowBackground(Color.clear)
                }
            }
        }
        .listStyle(.insetGrouped)
        .searchable(text: $viewModel.filter.searchText, prompt: "Notlarda ara")
        .onChange(of: viewModel.filter.searchText) { _, _ in viewModel.load() }
        .onChange(of: viewModel.period) { _, _ in viewModel.load() }
        .onChange(of: viewModel.periodOffset) { _, _ in viewModel.load() }
        .refreshable {
            await exchangeRates.refresh()
            await session.syncService.syncIfPossible()
            viewModel.load()
        }
    }

    // MARK: - Kurulum

    private var currentConverter: CurrencyConverter {
        CurrencyConverter(snapshot: exchangeRates.snapshot, mainCurrency: settings.mainCurrency)
    }

    private func prepare() {
        if viewModel == nil {
            let model = TransactionListViewModel(session: session, converter: currentConverter)
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
