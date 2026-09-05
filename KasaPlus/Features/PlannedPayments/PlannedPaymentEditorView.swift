import SwiftUI

struct PlannedPaymentEditorView: View {

    @Environment(AppSession.self) private var session
    @Environment(AppSettings.self) private var settings
    @Environment(ExchangeRateService.self) private var exchangeRates
    @Environment(NotificationService.self) private var notifications
    @Environment(\.dismiss) private var dismiss

    @State var draft: PlannedPaymentDraft
    @State private var errorMessage: String?

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
                        AmountField(
                            amount: $draft.amount,
                            tint: AppTheme.expense,
                            fontSize: 30
                        )

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
                            selection: $draft.bankID
                        )
                    }
                }

                Section {
                    DatePicker(
                        draft.isRecurring ? "Başlangıç tarihi" : "Vade tarihi",
                        selection: $draft.dueDate,
                        displayedComponents: [.date, .hourAndMinute]
                    )
                    .environment(\.locale, Formatters.locale)

                    Toggle(isOn: $draft.isRecurring) {
                        Label("Tekrarlayan ödeme", systemImage: "repeat")
                    }

                    if draft.isRecurring {
                        Picker("Tekrarlama", selection: $draft.recurrenceFrequency) {
                            ForEach(RecurrenceFrequency.allCases) { frequency in
                                Text(frequency.title).tag(frequency)
                            }
                        }
                        .pickerStyle(.segmented)

                        DatePicker(
                            "Bitiş tarihi",
                            selection: $draft.recurrenceEndDate,
                            in: draft.dueDate...,
                            displayedComponents: .date
                        )
                        .environment(\.locale, Formatters.locale)

                        Label(
                            "\(draft.recurrenceOccurrenceCount) planlı ödeme oluşturulacak",
                            systemImage: "calendar.badge.plus"
                        )
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                    }

                    Toggle(isOn: $draft.reminderEnabled) {
                        Label("Hatırlat", systemImage: "bell.badge")
                    }
                } header: {
                    Text("Vade")
                }

                Section {
                    if expenseCategories.isEmpty {
                        CategoryEmptyRow(message: "Gider kategorisi yok. Eklemek için dokunun.")
                    } else {
                        CategoryPickerGrid(
                            categories: expenseCategories,
                            selection: $draft.categoryID
                        )
                        .listRowInsets(EdgeInsets(top: 12, leading: 16, bottom: 12, trailing: 16))
                    }
                } header: {
                    CategorySectionHeader()
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
            .task {
                if draft.categoryID == nil {
                    draft.categoryID = expenseCategories.first?.id
                }
                if draft.bankID == nil, draft.paymentMethod.requiresBank {
                    draft.bankID = session.banks.first?.id
                }
            }
            .onChange(of: session.dataVersion) { _, _ in
                // Kategori yönetiminden dönüldüğünde seçim hâlâ geçerli mi?
                if draft.categoryID == nil
                    || !expenseCategories.contains(where: { $0.id == draft.categoryID }) {
                    draft.categoryID = expenseCategories.first?.id
                }
            }
            .onChange(of: draft.paymentMethod) { _, newValue in
                if newValue.requiresBank, draft.bankID == nil {
                    draft.bankID = session.banks.first?.id
                }
            }
            .onChange(of: draft.isRecurring) { _, isRecurring in
                guard isRecurring, draft.recurrenceEndDate < draft.dueDate else { return }
                draft.recurrenceEndDate = draft.dueDate.adding(.year, 1)
            }
            .onChange(of: draft.dueDate) { _, startDate in
                guard draft.isRecurring, draft.recurrenceEndDate < startDate else { return }
                draft.recurrenceEndDate = startDate.adding(.year, 1)
            }
        }
        .presentationDragIndicator(.visible)
    }

    private var converter: CurrencyConverter {
        CurrencyConverter(snapshot: exchangeRates.snapshot, mainCurrency: settings.mainCurrency)
    }

    private func save() {
        guard draft.isValid else {
            errorMessage = L10n.text("Başlık, tutar ve kategori zorunludur.")
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
            errorMessage = session.lastErrorMessage ?? L10n.text("Kayıt kaydedilemedi.")
        }
    }
}

// MARK: - Banka seçim satırı (işlem ve planlı ödeme ekranlarında ortak)

struct BankPickerRow: View {
    let banks: [Bank]
    @Binding var selection: UUID?

    var body: some View {
        if banks.isEmpty {
            Label("Banka yok. Ayarlar > Bankalar'dan ekleyin.", systemImage: "exclamationmark.triangle")
                .font(.footnote)
                .foregroundStyle(.secondary)
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
        }
    }
}
