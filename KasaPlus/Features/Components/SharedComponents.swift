import SwiftUI

// MARK: - Kategori rozeti

struct CategoryIconBadge: View {
    let iconName: String
    let colorHex: String
    var size: CGFloat = 38

    var body: some View {
        let color = Color(hex: colorHex)
        return Image(systemName: iconName)
            .font(.system(size: size * 0.42, weight: .semibold))
            .foregroundStyle(color)
            .frame(width: size, height: size)
            .background(color.opacity(0.15), in: RoundedRectangle(cornerRadius: size * 0.29, style: .continuous))
            .accessibilityHidden(true)
    }
}

// MARK: - Kart kabı

struct CardContainer<Content: View>: View {
    var padding: CGFloat = AppTheme.cardPadding
    @ViewBuilder var content: Content

    var body: some View {
        content
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: AppTheme.cardCornerRadius, style: .continuous)
                    .fill(Color(.secondarySystemGroupedBackground))
            )
    }
}

// MARK: - Özet kutucuğu

struct SummaryTile: View {
    let title: String
    let amount: Double
    let currency: Currency
    let tint: Color
    var systemImage: String?
    var showsSign: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                if let systemImage {
                    Image(systemName: systemImage)
                        .font(.caption)
                        .foregroundStyle(tint)
                }
                Text(title)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Text(Formatters.money(amount, currency: currency, showsSign: showsSign))
                .font(.title3.weight(.semibold))
                .foregroundStyle(tint)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
                .contentTransition(.numericText())
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Boş durum

struct EmptyStateView: View {
    let systemImage: String
    let title: String
    let message: String
    var actionTitle: String?
    var action: (() -> Void)?

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: systemImage)
                .font(.system(size: 40))
                .foregroundStyle(.tertiary)
            Text(title)
                .font(.headline)
            Text(message)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            if let actionTitle, let action {
                Button(actionTitle, action: action)
                    .buttonStyle(.borderedProminent)
                    .padding(.top, 4)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
        .padding(.horizontal, 24)
    }
}

// MARK: - Dönem seçici (◀ Ekim 2026 ▶)

struct PeriodNavigator: View {
    @Binding var period: ReportPeriod
    @Binding var offset: Int
    let range: PeriodRange

    var body: some View {
        VStack(spacing: 10) {
            Picker("Dönem", selection: $period) {
                ForEach(ReportPeriod.allCases) { value in
                    Text(value.title).tag(value)
                }
            }
            .pickerStyle(.segmented)
            .onChange(of: period) { _, _ in offset = 0 }

            HStack {
                Button {
                    offset -= 1
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.footnote.weight(.semibold))
                        .frame(width: 32, height: 32)
                }
                .accessibilityLabel("Önceki dönem")

                Spacer()

                Text(range.title)
                    .font(.subheadline.weight(.semibold))
                    .contentTransition(.numericText())

                Spacer()

                Button {
                    offset += 1
                } label: {
                    Image(systemName: "chevron.right")
                        .font(.footnote.weight(.semibold))
                        .frame(width: 32, height: 32)
                }
                .disabled(offset >= 0)
                .accessibilityLabel("Sonraki dönem")
            }
            .buttonStyle(.bordered)
            .buttonBorderShape(.circle)
        }
    }
}

// MARK: - Değişim rozeti (▲ %12,4)

struct ChangeBadge: View {
    let change: Double?
    /// Artışın "iyi" sayılıp sayılmayacağı (gelirde iyi, giderde kötü).
    var increaseIsPositive: Bool = true

    var body: some View {
        if let change {
            let isIncrease = change >= 0
            let isGood = isIncrease == increaseIsPositive
            let tint = abs(change) < 0.05 ? Color.secondary : (isGood ? AppTheme.income : AppTheme.expense)

            HStack(spacing: 2) {
                Image(systemName: isIncrease ? "arrow.up.right" : "arrow.down.right")
                    .font(.caption2.weight(.bold))
                Text(Formatters.percent(change))
                    .font(.caption.weight(.semibold))
            }
            .foregroundStyle(tint)
            .padding(.horizontal, 7)
            .padding(.vertical, 3)
            .background(tint.opacity(0.12), in: Capsule())
            .accessibilityLabel(isIncrease ? "\(Formatters.percent(change)) artış" : "\(Formatters.percent(change)) azalış")
        } else {
            Text("—")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
    }
}

// MARK: - Uyarı şeridi

struct InlineNotice: View {
    let systemImage: String
    let message: String
    var tint: Color = .orange

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: systemImage)
                .font(.caption)
            Text(message)
                .font(.caption)
                .fixedSize(horizontal: false, vertical: true)
        }
        .foregroundStyle(tint)
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(tint.opacity(0.1), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
    }
}
