import SwiftUI

/// "Ertele" seçildiğinde açılan tarih seçme yaprağı.
/// Bildirimdeki Ertele butonu da uygulamayı öne getirip bu ekranı açar.
struct PostponeSheet: View {

    let payment: PlannedPayment
    let onConfirm: (Date) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var newDate: Date

    private let calendar = Calendar.turkish

    init(payment: PlannedPayment, onConfirm: @escaping (Date) -> Void) {
        self.payment = payment
        self.onConfirm = onConfirm
        // Vadesi geçmişse bugünden, geçmemişse mevcut vadeden ileriye sayalım.
        let base = max(payment.dueDate, Date())
        _newDate = State(initialValue: Calendar.turkish.date(byAdding: .day, value: 7, to: base) ?? base)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    LabeledContent("Ödeme") {
                        Text(payment.title)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                    LabeledContent("Tutar") {
                        Text(Formatters.money(payment.amount, currency: payment.currency))
                            .foregroundStyle(.secondary)
                    }
                    LabeledContent("Mevcut vade") {
                        Text(Formatters.dayHeader.string(from: payment.dueDate))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                    }
                }

                Section("Hızlı seçim") {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            quickButton("1 gün", days: 1)
                            quickButton("3 gün", days: 3)
                            quickButton("1 hafta", days: 7)
                            quickButton("15 gün", days: 15)
                            quickButton("1 ay", days: 30)
                        }
                        .padding(.vertical, 2)
                    }
                }

                Section("Yeni vade") {
                    DatePicker(
                        "Tarih ve saat",
                        selection: $newDate,
                        in: Date()...,
                        displayedComponents: [.date, .hourAndMinute]
                    )
                    .datePickerStyle(.graphical)
                    .environment(\.locale, Formatters.locale)
                }

                Section {
                    Text("Hatırlatmalar yeni vadeye göre yeniden kurulur: 1 hafta önce, 1 gün önce ve vade günü.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Ertele")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Vazgeç") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Ertele") {
                        onConfirm(newDate)
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
        }
    }

    private func quickButton(_ title: String, days: Int) -> some View {
        Button(title) {
            let base = max(payment.dueDate, Date())
            newDate = calendar.date(byAdding: .day, value: days, to: base) ?? base
        }
        .font(.caption.weight(.medium))
        .buttonStyle(.bordered)
    }
}
