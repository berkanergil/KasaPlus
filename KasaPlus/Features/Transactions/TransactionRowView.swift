import SwiftUI

struct TransactionRowView: View {

    let transaction: FinanceTransaction
    let category: Category?
    let bankName: String?
    let converter: CurrencyConverter

    var body: some View {
        HStack(spacing: 12) {
            CategoryIconBadge(
                iconName: category?.iconName ?? "questionmark.circle.fill",
                colorHex: category?.colorHex ?? "#889096"
            )

            VStack(alignment: .leading, spacing: 3) {
                Text(category?.name ?? "Silinmiş kategori")
                    .font(.subheadline.weight(.medium))
                    .lineLimit(1)

                HStack(spacing: 5) {
                    Image(systemName: transaction.paymentMethod.systemImage)
                    Text(transaction.paymentMethod.shortTitle)

                    if let bankName {
                        Text("·")
                        Text(bankName).lineLimit(1)
                    }
                    if let note = transaction.note, !note.isEmpty {
                        Text("·")
                        Text(note).lineLimit(1)
                    }
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }

            Spacer(minLength: 8)

            VStack(alignment: .trailing, spacing: 2) {
                // Her kayıt girildiği orijinal para birimiyle gösterilir (PRD 5.1.1).
                Text(Formatters.money(transaction.amount, currency: transaction.currency))
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(transaction.type.tintColor)
                    .lineLimit(1)

                if let secondary = converter.secondaryAmountText(for: transaction) {
                    Text(secondary)
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                        .lineLimit(1)
                }
            }
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityText)
    }

    private var accessibilityText: String {
        let typeText = transaction.type.title
        let amountText = Formatters.money(transaction.amount, currency: transaction.currency)
        let categoryText = category?.name ?? "Silinmiş kategori"
        let bankText = bankName.map { ", \($0)" } ?? ""
        return "\(typeText), \(categoryText), \(amountText), \(transaction.paymentMethod.title)\(bankText)"
    }
}
