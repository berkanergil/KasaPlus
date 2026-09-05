import SwiftUI

/// Tarih aralığı, kategori, tür ve ödeme yöntemi filtreleri (PRD 5.3).
struct TransactionFilterView: View {

    @Bindable var viewModel: TransactionListViewModel

    @Environment(AppSession.self) private var session
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section("Tür") {
                    ForEach(TransactionType.allCases) { type in
                        MultiSelectRow(
                            title: type.title,
                            systemImage: type.systemImage,
                            tint: type.tintColor,
                            isOn: binding(for: type)
                        )
                    }
                }

                Section("Ödeme Yöntemi") {
                    ForEach(PaymentMethod.allCases) { method in
                        MultiSelectRow(
                            title: method.title,
                            systemImage: method.systemImage,
                            tint: AppTheme.accent,
                            isOn: binding(for: method)
                        )
                    }
                }

                Section("Bankalar") {
                    if session.banks.isEmpty {
                        Text("Kayıtlı banka yok.")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(session.banks) { bank in
                            MultiSelectRow(
                                title: bank.name,
                                systemImage: "building.columns",
                                tint: AppTheme.accent,
                                isOn: bankBinding(for: bank.id)
                            )
                        }
                    }
                }

                Section {
                    if session.categories.isEmpty {
                        CategoryEmptyRow(message: "Kategori bulunamadı. Eklemek için dokunun.")
                    } else {
                        ForEach(session.categories) { category in
                            MultiSelectRow(
                                title: category.name,
                                systemImage: category.iconName,
                                tint: Color(hex: category.colorHex),
                                isOn: binding(for: category.id)
                            )
                        }
                    }
                } header: {
                    CategorySectionHeader(title: "Kategoriler")
                }

                Section {
                    Button("Tüm filtreleri temizle", role: .destructive) {
                        viewModel.resetFilter()
                    }
                    .disabled(!viewModel.filter.isActive)
                }
            }
            .navigationTitle("Filtrele")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Uygula") {
                        viewModel.load()
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
        }
    }

    // MARK: - Binding yardımcıları

    private func binding(for type: TransactionType) -> Binding<Bool> {
        Binding(
            get: { viewModel.filter.types.contains(type) },
            set: { isOn in
                if isOn { viewModel.filter.types.insert(type) } else { viewModel.filter.types.remove(type) }
            }
        )
    }

    private func binding(for method: PaymentMethod) -> Binding<Bool> {
        Binding(
            get: { viewModel.filter.paymentMethods.contains(method) },
            set: { isOn in
                if isOn { viewModel.filter.paymentMethods.insert(method) } else { viewModel.filter.paymentMethods.remove(method) }
            }
        )
    }

    private func bankBinding(for bankID: UUID) -> Binding<Bool> {
        Binding(
            get: { viewModel.filter.bankIDs.contains(bankID) },
            set: { isOn in
                if isOn { viewModel.filter.bankIDs.insert(bankID) } else { viewModel.filter.bankIDs.remove(bankID) }
            }
        )
    }

    private func binding(for categoryID: UUID) -> Binding<Bool> {
        Binding(
            get: { viewModel.filter.categoryIDs.contains(categoryID) },
            set: { isOn in
                if isOn { viewModel.filter.categoryIDs.insert(categoryID) } else { viewModel.filter.categoryIDs.remove(categoryID) }
            }
        )
    }
}

private struct MultiSelectRow: View {
    let title: String
    let systemImage: String
    let tint: Color
    @Binding var isOn: Bool

    var body: some View {
        Button {
            isOn.toggle()
        } label: {
            HStack(spacing: 12) {
                Image(systemName: systemImage)
                    .foregroundStyle(tint)
                    .frame(width: 24)
                Text(title)
                    .foregroundStyle(.primary)
                Spacer()
                if isOn {
                    Image(systemName: "checkmark")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(AppTheme.accent)
                }
            }
        }
        .accessibilityAddTraits(isOn ? [.isSelected, .isButton] : .isButton)
    }
}
