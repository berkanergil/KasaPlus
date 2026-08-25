import SwiftUI

struct PlannedPaymentListView: View {

    @Environment(AppSession.self) private var session
    @Environment(AppSettings.self) private var settings
    @Environment(ExchangeRateService.self) private var exchangeRates
    @Environment(NotificationService.self) private var notifications

    @State private var viewModel: PlannedPaymentListViewModel?
    @State private var editorRequest: PlannedPaymentEditorRequest?
    @State private var pendingDeletion: PlannedPayment?
    @State private var postponeTarget: PlannedPayment?
    @State private var paidConfirmation: PlannedPayment?

    /// Bildirimden "Ertele" ile gelindiğinde açılacak ödeme.
    let postponeRequestID: UUID?
    let onPostponeHandled: () -> Void

    var body: some View {
        NavigationStack {
            Group {
                if let viewModel {
                    content(viewModel)
                } else {
                    ProgressView()
                }
            }
            .navigationTitle("Planlı Ödemeler")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        editorRequest = PlannedPaymentEditorRequest(
                            draft: .empty(currency: settings.defaultEntryCurrency)
                        )
                    } label: {
                        Image(systemName: "plus")
                    }
                    .accessibilityLabel("Yeni planlı ödeme")
                }
            }
        }
        .task { prepare() }
        .onChange(of: session.dataVersion) { _, _ in viewModel?.load() }
        .onChange(of: settings.mainCurrency) { _, _ in refreshConverter() }
        .onChange(of: exchangeRates.snapshot) { _, _ in refreshConverter() }
        .onChange(of: postponeRequestID) { _, newValue in openPostponeIfNeeded(newValue) }
        .sheet(item: $editorRequest) { request in
            PlannedPaymentEditorView(draft: request.draft)
        }
        .sheet(item: $postponeTarget) { payment in
            PostponeSheet(payment: payment) { newDate in
                session.postponePlannedPayment(id: payment.id, to: newDate)
            }
        }
        .confirmationDialog(
            "Planlanan ödemeyi sil",
            isPresented: Binding(
                get: { pendingDeletion != nil },
                set: { if !$0 { pendingDeletion = nil } }
            ),
            titleVisibility: .visible
        ) {
            Button("Sil", role: .destructive) {
                if let pendingDeletion { session.deletePlannedPayment(id: pendingDeletion.id) }
                pendingDeletion = nil
            }
            Button("Vazgeç", role: .cancel) { pendingDeletion = nil }
        } message: {
            Text("Hatırlatmaları da iptal edilecek. Bu işlem geri alınamaz.")
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
            Button("Ertele") {
                postponeTarget = paidConfirmation
                paidConfirmation = nil
            }
            Button("Vazgeç", role: .cancel) { paidConfirmation = nil }
        } message: {
            if let paidConfirmation {
                Text("\(paidConfirmation.title) — \(Formatters.money(paidConfirmation.amount, currency: paidConfirmation.currency)) tutarında bir gider kaydı oluşturulacak.")
            }
        }
    }

    // MARK: - İçerik

    @ViewBuilder
    private func content(_ viewModel: PlannedPaymentListViewModel) -> some View {
        @Bindable var viewModel = viewModel

        List {
            Section {
                VStack(alignment: .leading, spacing: 12) {
                    HStack(spacing: 12) {
                        SummaryTile(
                            title: "Bekleyen toplam",
                            amount: viewModel.pendingTotal,
                            currency: settings.mainCurrency,
                            tint: AppTheme.expense,
                            systemImage: "clock.fill"
                        )
                        if viewModel.overdueCount > 0 {
                            Divider().frame(height: 32)
                            VStack(alignment: .leading, spacing: 6) {
                                Text("Gecikmiş")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                Text("\(viewModel.overdueCount) ödeme")
                                    .font(.title3.weight(.semibold))
                                    .foregroundStyle(AppTheme.expense)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }

                    if notifications.authorizationStatus == .denied {
                        InlineNotice(
                            systemImage: "bell.slash.fill",
                            message: "Bildirimler kapalı. Hatırlatma alabilmek için iOS Ayarlar ▸ Kasa+ ▸ Bildirimler'i açın."
                        )
                    } else if notifications.authorizationStatus == .notDetermined {
                        Button {
                            Task {
                                await notifications.requestAuthorizationIfNeeded()
                                session.scheduleReminders()
                            }
                        } label: {
                            Label("Hatırlatmalara izin ver", systemImage: "bell.badge")
                                .font(.footnote.weight(.medium))
                        }
                    }

                    if viewModel.hasUnconvertedAmounts {
                        InlineNotice(
                            systemImage: "exclamationmark.triangle.fill",
                            message: "Bazı ödemelerin kuru bulunamadı; toplam çevrilmeden hesaplandı."
                        )
                    }

                    Toggle("Ödenenleri göster", isOn: $viewModel.showsPaid)
                        .font(.footnote)
                        .onChange(of: viewModel.showsPaid) { _, _ in viewModel.load() }
                }
                .padding(.vertical, 4)
            }

            if viewModel.isEmpty {
                Section {
                    EmptyStateView(
                        systemImage: "calendar.badge.clock",
                        title: "Planlı ödeme yok",
                        message: "Kira, fatura, çek veya tedarikçi ödemelerinizi buraya ekleyin. Vadeden 1 hafta ve 1 gün önce hatırlatırız.",
                        actionTitle: "Ödeme planla",
                        action: {
                            editorRequest = PlannedPaymentEditorRequest(
                                draft: .empty(currency: settings.defaultEntryCurrency)
                            )
                        }
                    )
                    .listRowBackground(Color.clear)
                }
            } else {
                ForEach(viewModel.sections) { section in
                    Section {
                        ForEach(section.items) { payment in
                            Button {
                                editorRequest = PlannedPaymentEditorRequest(
                                    draft: PlannedPaymentDraft(payment: payment)
                                )
                            } label: {
                                PlannedPaymentRowView(
                                    payment: payment,
                                    category: viewModel.category(for: payment),
                                    bankName: viewModel.bankName(for: payment),
                                    secondaryAmountText: viewModel.secondaryAmountText(for: payment)
                                )
                            }
                            .buttonStyle(.plain)
                            .swipeActions(edge: .leading, allowsFullSwipe: true) {
                                if payment.status == .pending {
                                    Button {
                                        paidConfirmation = payment
                                    } label: {
                                        Label("Ödedim", systemImage: "checkmark.circle.fill")
                                    }
                                    .tint(AppTheme.income)
                                } else {
                                    Button {
                                        session.markPlannedPaymentPending(id: payment.id)
                                    } label: {
                                        Label("Geri al", systemImage: "arrow.uturn.backward")
                                    }
                                    .tint(.orange)
                                }
                            }
                            .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                Button(role: .destructive) {
                                    pendingDeletion = payment
                                } label: {
                                    Label("Sil", systemImage: "trash")
                                }
                                if payment.status == .pending {
                                    Button {
                                        postponeTarget = payment
                                    } label: {
                                        Label("Ertele", systemImage: "calendar.badge.plus")
                                    }
                                    .tint(AppTheme.accent)
                                }
                            }
                        }
                    } header: {
                        Label(section.title, systemImage: section.systemImage)
                            .font(.caption)
                            .textCase(nil)
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
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
            let model = PlannedPaymentListViewModel(session: session, converter: currentConverter)
            model.load()
            viewModel = model
        } else {
            refreshConverter()
        }
        openPostponeIfNeeded(postponeRequestID)
    }

    private func refreshConverter() {
        viewModel?.updateConverter(currentConverter)
        viewModel?.load()
    }

    private func openPostponeIfNeeded(_ id: UUID?) {
        guard let id, let payment = session.plannedPayment(id: id) else { return }
        postponeTarget = payment
        onPostponeHandled()
    }
}

/// `sheet(item:)` için kimlikli kap.
struct PlannedPaymentEditorRequest: Identifiable {
    let id = UUID()
    var draft: PlannedPaymentDraft
}
