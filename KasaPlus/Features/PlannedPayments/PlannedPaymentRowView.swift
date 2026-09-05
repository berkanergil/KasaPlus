import SwiftUI

struct PlannedPaymentRowView: View {

    let payment: PlannedPayment
    let category: Category?
    let bankName: String?
    let secondaryAmountText: String?

    var body: some View {
        HStack(spacing: 12) {
            CategoryIconBadge(
                iconName: category?.iconName ?? "calendar",
                colorHex: category?.colorHex ?? "#889096"
            )

            VStack(alignment: .leading, spacing: 3) {
                Text(payment.title)
                    .font(.subheadline.weight(.medium))
                    .lineLimit(1)

                HStack(spacing: 5) {
                    Image(systemName: payment.paymentMethod.systemImage)
                    Text(payment.paymentMethod.shortTitle)
                    if let bankName {
                        Text("·")
                        Text(bankName).lineLimit(1)
                    }
                }
                .font(.caption)
                .foregroundStyle(.secondary)

                HStack(spacing: 6) {
                    Text(payment.dueDescription())
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(statusTint)

                    if payment.postponeCount > 0 {
                        Text("· \(payment.postponeCount)× ertelendi")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                    if payment.status == .pending && !payment.reminderEnabled {
                        Image(systemName: "bell.slash")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                    if let frequency = payment.recurrenceFrequency {
                        Label(frequency.shortTitle, systemImage: "repeat")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                }
            }

            Spacer(minLength: 8)

            VStack(alignment: .trailing, spacing: 2) {
                Text(Formatters.money(payment.amount, currency: payment.currency))
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(payment.status == .paid ? Color.secondary : AppTheme.expense)
                    .lineLimit(1)
                    .strikethrough(payment.status == .paid)

                if let secondaryAmountText {
                    Text(secondaryAmountText)
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                        .lineLimit(1)
                }

                Text(Formatters.shortDay.string(from: payment.dueDate))
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityLabel(
            "\(payment.title), \(Formatters.money(payment.amount, currency: payment.currency)), \(payment.dueDescription())"
        )
    }

    private var statusTint: Color {
        switch payment.status {
        case .paid: return AppTheme.income
        case .cancelled: return .secondary
        case .pending:
            let days = payment.daysRemaining()
            if days < 0 { return AppTheme.expense }
            if days <= 1 { return .orange }
            return .secondary
        }
    }
}
