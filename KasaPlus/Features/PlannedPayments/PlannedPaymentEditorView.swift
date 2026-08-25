import SwiftUI

struct PlannedPaymentEditorView: View {

    @Environment(AppSession.self) private var session
    @Environment(AppSettings.self) private var settings
    @Environment(ExchangeRateService.self) private var exchangeRates
    @Environment(NotificationService.self) private var notifications
    @Environment(\.dismiss) private var dismiss

    @State var draft: PlannedPaymentDraft
    @State private var errorMessage: String?
    @State private var isCategoryManagerPresented = false
    @State private var isBankManagerPresented = false

    private var isEditing: Bool { draft.id != nil }

    private var expenseCategories: [Category] { session.categories(for: .expense) }

    var body: some View {
        NavigationStack {
            Form {
                Section("Ödeme") {
                    TextField("Başlık — örn. Dükkân kirası", text: $draft.title)
                        .textInputAutocapitalization(.sentences)
                }

                Section("Tutar") {
                    HStack(spacing: 12) {
                        TextField("0,00", value: $draft.amount, format: .number.precision(.fractionLength(0...2)))
                            .keyboardType(.decimalPad)
                            .font(.system(size: 30, weight: .semibold, design: .rounded))
                            .foregroundStyle(AppTheme.expense)

                        Picker("Para birimi", selection: $draft.currency) {
                            ForEach(Currency.allCases) { currency in
                                Text(currency.displayName).tag(currency)
                            }
                        }
                        .pickerStyle(.menu)
                        .labelsHidden()
                    }

                    if draft.currency != settings.mainCurrency,
                       let converted = converter.convert(draft.amount, from: draft.currency) {
                        LabeledContent("Karşılığı") {
                            Text(Formatters.money(converted, currency: settings.mainCurrency))
                                .foregroundStyle(.secondary)
                        }
                        .font(.footnote)
                    }
                }

                Section {
                    DatePicker(
                        "Vade tarihi",
                        selection: $draft.dueDate,
                        displayedComponents: [.date, .hourAndMinute]
                    )
                    .environment(\.locale, Formatters.locale)

                    Toggle(isOn: $draft.reminderEnabled) {
                        Label("Hatırlat", systemImage: "bell.badge")
                    }
                } header: {
                    Text("Vade")
                } footer: {
                    if draft.reminderEnabled {
                        Text("Vadeden 1 hafta önce, 1 gün önce ve vade günü bildirim alırsınız. Vade günü bildiriminde \"Ödedim\" ve \"Ertele\" butonları bulunur.")
                    } else {
                        Text("Bu ödeme için bildirim gönderilmez.")
                    }
                }

                Section {
                    if expenseCategories.isEmpty {
                        Button {
                            isCategoryManagerPresented = true
                        } label: {
                            Label("Gider kategorisi ekleyin", systemImage: "plus.circle")
                        }
                    } else {
                        CategoryPickerGrid(
                            categories: expenseCategories,
                            selection: $draft.categoryID
                        )
                        .listRowInsets(EdgeInsets(top: 12, leading: 16, bottom: 12, trailing: 16))
                    }
                } header: {
                    HStack {
                        Text("Kategori")
                        Spacer()
                        Button("Yönet") { isCategoryManagerPresented = true }
                            .font(.caption)
                            .textCase(nil)
                    }
                }

                Section("Ödeme Yöntemi") {
                    Picker(selection: $draft.paymentMethod) {
                        ForEach(PaymentMethod.allCases) { method in
                            Label(method.title, systemImage: method.systemImage).tag(method)
                        }
                    } label: {
                        Text("Yöntem")
                    }
                    .pickerStyle(.navigationLink)

                    if draft.paymentMethod.requiresBank {
                        BankPickerRow(
                            banks: session.banks,
                            selection: $draft.bankID,
                            onManage: { isBankManagerPresented = true }
                        )
                    }
                }

                Section("Not (opsiyonel)") {
                    TextField("Örn. 3 aylık peşin", text: $draft.note, axis: .vertical)
                        .lineLimit(1...4)
                }

                if let errorMessage {
                    Section {
                        Text(errorMessage)
                            .font(.footnote)
                            .foregroundStyle(AppTheme.expense)
                    }
                }
            }
            .navigationTitle(isEditing ? "Planlı Ödemeyi Düzenle" : "Yeni Planlı Ödeme")
            .navigationBarTitleDisplayMode(.inline)
            .scrollDismissesKeyboard(.interactively)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Vazgeç") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Kaydet") { save() }
                        .fontWeight(.semibold)
                        .disabled(!draft.isValid)
                }
            }
            .sheet(isPresented: $isCategoryManagerPresented) {
                CategoryManagementView()
            }
            .sheet(isPresented: $isBankManagerPresented) {
                BankManagementView()
            }
            .task {
                if draft.categoryID == nil {
                    draft.categoryID = expenseCategories.first?.id
                }
                if draft.bankID == nil, draft.paymentMethod.requiresBank {
                    draft.bankID = session.banks.first?.id
                }
            }
            .onChange(of: draft.paymentMethod) { _, newValue in
                if newValue.requiresBank, draft.bankID == nil {
                    draft.bankID = session.banks.first?.id
                }
            }
        }
        .presentationDragIndicator(.visible)
    }

    private var converter: CurrencyConverter {
        CurrencyConverter(snapshot: exchangeRates.snapshot, mainCurrency: settings.mainCurrency)
    }

    private func save() {
        guard draft.isValid else {
            errorMessage = "Başlık, tutar ve kategori zorunludur."
            return
        }
        if session.savePlannedPayment(draft) {
            if draft.reminderEnabled {
                Task {
                    await notifications.requestAuthorizationIfNeeded()
                    session.scheduleReminders()
                }
            }
            dismiss()
        } else {
            errorMessage = session.lastErrorMessage ?? "Kayıt kaydedilemedi."
        }
    }
}

// MARK: - Banka seçim satırı (işlem ve planlı ödeme ekranlarında ortak)

struct BankPickerRow: View {
    let banks: [Bank]
    @Binding var selection: UUID?
    let onManage: () -> Void

    var body: some View {
        if banks.isEmpty {
            Button {
                onManage()
            } label: {
                Label("Banka ekleyin", systemImage: "plus.circle")
            }
        } else {
            Picker(selection: $selection) {
                Text("Seçilmedi").tag(UUID?.none)
                ForEach(banks) { bank in
                    Text(bank.name).tag(UUID?.some(bank.id))
                }
            } label: {
                Text("Banka")
            }
            .pickerStyle(.navigationLink)

            Button {
                onManage()
            } label: {
                Label("Bankaları yönet", systemImage: "building.columns")
                    .font(.footnote)
            }
        }
    }
}
