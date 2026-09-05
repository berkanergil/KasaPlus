import SwiftUI

struct TransactionEditorView: View {

    enum Mode: Identifiable {
        case create(type: TransactionType)
        case edit(transaction: FinanceTransaction)

        var id: String {
            switch self {
            case .create(let type): return "create-\(type.rawValue)"
            case .edit(let transaction): return "edit-\(transaction.id.uuidString)"
            }
        }
    }

    let mode: Mode

    @Environment(AppSession.self) private var session
    @Environment(AppSettings.self) private var settings
    @Environment(ExchangeRateService.self) private var exchangeRates
    @Environment(\.dismiss) private var dismiss

    @State private var viewModel: TransactionEditorViewModel?
    @FocusState private var isAmountFocused: Bool

    var body: some View {
        NavigationStack {
            Group {
                if let viewModel {
                    form(viewModel)
                } else {
                    ProgressView()
                }
            }
            .navigationTitle(viewModel?.title ?? "")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Vazgeç") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Kaydet") {
                        if viewModel?.save() == true { dismiss() }
                    }
                    .fontWeight(.semibold)
                    .disabled(viewModel?.canSave != true)
                }
            }
        }
        .task {
            if viewModel == nil {
                viewModel = TransactionEditorViewModel(
                    session: session,
                    mode: mode,
                    defaultCurrency: settings.defaultEntryCurrency
                )
                viewModel?.paymentMethodDidChange()
                isAmountFocused = true
            }
        }
        .presentationDragIndicator(.visible)
    }

    // MARK: - Form

    @ViewBuilder
    private func form(_ viewModel: TransactionEditorViewModel) -> some View {
        @Bindable var viewModel = viewModel

        Form {
            // Tür
            Section {
                Picker("Tür", selection: $viewModel.draft.type) {
                    ForEach(TransactionType.allCases) { type in
                        Text(type.title).tag(type)
                    }
                }
                .pickerStyle(.segmented)
                .onChange(of: viewModel.draft.type) { _, _ in viewModel.typeDidChange() }
            }
            .listRowBackground(Color.clear)
            .listRowInsets(EdgeInsets(top: 4, leading: 0, bottom: 8, trailing: 0))

            // Tutar + para birimi
            Section("Tutar") {
                HStack(spacing: 12) {
                    AmountField(
                        amount: $viewModel.draft.amount,
                        tint: viewModel.draft.type.tintColor,
                        fontSize: 34,
                        focus: $isAmountFocused
                    )

                    Picker("Para birimi", selection: $viewModel.draft.currency) {
                        ForEach(Currency.allCases) { currency in
                            Text(currency.displayName).tag(currency)
                        }
                    }
                    .pickerStyle(.menu)
                    .labelsHidden()
                }

                // Hızlı tutar ekleme
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        Button {
                            viewModel.clearAmount()
                        } label: {
                            Label("Sıfırla", systemImage: "arrow.counterclockwise")
                                .font(.caption)
                        }
                        .buttonStyle(.bordered)

                        ForEach(viewModel.quickAmounts, id: \.self) { value in
                            Button("+\(Int(value))") {
                                viewModel.applyQuickAmount(value)
                            }
                            .font(.caption.weight(.medium))
                            .buttonStyle(.bordered)
                        }
                    }
                    .padding(.vertical, 2)
                }

                if viewModel.draft.currency != settings.mainCurrency,
                   let converted = converter.convert(viewModel.draft.amount, from: viewModel.draft.currency) {
                    LabeledContent("Karşılığı") {
                        Text(Formatters.money(converted, currency: settings.mainCurrency))
                            .foregroundStyle(.secondary)
                    }
                    .font(.footnote)
                }
            }

            // Ödeme yöntemi + banka
            Section("Ödeme Yöntemi") {
                Picker(selection: $viewModel.draft.paymentMethod) {
                    ForEach(PaymentMethod.allCases) { method in
                        Label(method.title, systemImage: method.systemImage).tag(method)
                    }
                } label: {
                    Text("Yöntem")
                }
                .pickerStyle(.navigationLink)
                .onChange(of: viewModel.draft.paymentMethod) { _, _ in
                    viewModel.paymentMethodDidChange()
                }

                if viewModel.draft.paymentMethod.requiresBank {
                    BankPickerRow(
                        banks: viewModel.availableBanks,
                        selection: $viewModel.draft.bankID
                    )
                }
            }

            // Kategori
            Section {
                if viewModel.hasNoCategories {
                    CategoryEmptyRow(message: "Bu türde kategori yok. Eklemek için dokunun.")
                } else {
                    CategoryPickerGrid(
                        categories: viewModel.availableCategories,
                        selection: $viewModel.draft.categoryID
                    )
                    .listRowInsets(EdgeInsets(top: 12, leading: 16, bottom: 12, trailing: 16))
                }
            } header: {
                CategorySectionHeader()
            }

            // Tarih ve tekrarlama
            Section {
                DatePicker(
                    viewModel.draft.isRecurring ? "Başlangıç tarihi" : "Tarih",
                    selection: $viewModel.draft.date,
                    displayedComponents: [.date, .hourAndMinute]
                )
                .environment(\.locale, Formatters.locale)

                Toggle(isOn: $viewModel.draft.isRecurring) {
                    Label("Tekrarlayan kayıt", systemImage: "repeat")
                }

                if viewModel.draft.isRecurring {
                    Picker("Tekrarlama", selection: $viewModel.draft.recurrenceFrequency) {
                        ForEach(RecurrenceFrequency.allCases) { frequency in
                            Text(frequency.title).tag(frequency)
                        }
                    }
                    .pickerStyle(.segmented)

                    DatePicker(
                        "Bitiş tarihi",
                        selection: $viewModel.draft.recurrenceEndDate,
                        in: viewModel.draft.date...,
                        displayedComponents: .date
                    )
                    .environment(\.locale, Formatters.locale)

                    Label(
                        "\(viewModel.draft.recurrenceOccurrenceCount) kayıt oluşturulacak",
                        systemImage: "calendar.badge.plus"
                    )
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                }
            } header: {
                Text("Tarih")
            } footer: {
                if viewModel.draft.isRecurring {
                    Text("Başlangıç ve bitiş günleri dahil olmak üzere seçilen her dönem için ayrı bir gelir/gider kaydı oluşturulur.")
                }
            }
            .onChange(of: viewModel.draft.isRecurring) { _, isRecurring in
                guard isRecurring, viewModel.draft.recurrenceEndDate < viewModel.draft.date else { return }
                viewModel.draft.recurrenceEndDate = viewModel.draft.date.adding(.year, 1)
            }
            .onChange(of: viewModel.draft.date) { _, startDate in
                guard viewModel.draft.isRecurring, viewModel.draft.recurrenceEndDate < startDate else { return }
                viewModel.draft.recurrenceEndDate = startDate.adding(.year, 1)
            }

            // Not
            Section("Not (opsiyonel)") {
                TextField("Örn. Market alışverişi", text: $viewModel.draft.note, axis: .vertical)
                    .lineLimit(1...4)
            }

            if let errorMessage = viewModel.errorMessage {
                Section {
                    Text(errorMessage)
                        .font(.footnote)
                        .foregroundStyle(AppTheme.expense)
                }
            }
        }
        .scrollDismissesKeyboard(.interactively)
        .toolbar {
            if isAmountFocused {
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Bitti") { isAmountFocused = false }
                }
            }
        }
        .onChange(of: session.dataVersion) { _, _ in
            // Ayarlardan dönüldüğünde seçim hâlâ geçerli mi?
            viewModel.typeDidChange()
        }
    }

    private var converter: CurrencyConverter {
        CurrencyConverter(snapshot: exchangeRates.snapshot, mainCurrency: settings.mainCurrency)
    }
}

// MARK: - Kategori seçim ızgarası

struct CategoryPickerGrid: View {
    let categories: [Category]
    @Binding var selection: UUID?

    private let columns = [GridItem(.adaptive(minimum: 76, maximum: 110), spacing: 10)]

    var body: some View {
        LazyVGrid(columns: columns, spacing: 10) {
            ForEach(categories) { category in
                let isSelected = selection == category.id
                Button {
                    selection = category.id
                } label: {
                    VStack(spacing: 6) {
                        CategoryIconBadge(
                            iconName: category.iconName,
                            colorHex: category.colorHex,
                            size: 34
                        )
                        Text(category.name)
                            .font(.caption2)
                            .lineLimit(2)
                            .multilineTextAlignment(.center)
                            .foregroundStyle(isSelected ? Color.primary : .secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .background(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(isSelected ? Color(hex: category.colorHex).opacity(0.14) : Color.clear)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .stroke(isSelected ? Color(hex: category.colorHex) : Color.clear, lineWidth: 1.5)
                    )
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(isSelected ? [.isSelected, .isButton] : .isButton)
            }
        }
    }
}
