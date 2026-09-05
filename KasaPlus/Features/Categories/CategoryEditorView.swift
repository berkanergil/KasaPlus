import SwiftUI

/// Kategori ekleme / düzenleme: isim + ikon + renk (PRD 5.2).
struct CategoryEditorView: View {

    @Environment(AppSession.self) private var session
    @Environment(\.dismiss) private var dismiss

    @State var draft: CategoryDraft
    @State private var errorMessage: String?

    private let iconColumns = [GridItem(.adaptive(minimum: 46), spacing: 10)]
    private let colorColumns = [GridItem(.adaptive(minimum: 44), spacing: 10)]

    private var isEditing: Bool { draft.id != nil }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    HStack(spacing: 14) {
                        CategoryIconBadge(
                            iconName: draft.iconName,
                            colorHex: draft.colorHex,
                            size: 52
                        )
                        VStack(alignment: .leading, spacing: 2) {
                            Text(draft.name.isEmpty ? "Kategori adı" : draft.name)
                                .font(.headline)
                                .foregroundStyle(draft.name.isEmpty ? .secondary : .primary)
                            Text(draft.type.title)
                                .font(.caption)
                                .foregroundStyle(draft.type.tintColor)
                        }
                    }
                    .padding(.vertical, 4)
                }

                Section("Ad") {
                    TextField("Örn. Kozmetik Satışı", text: $draft.name)
                        .textInputAutocapitalization(.words)
                }

                Section("Tür") {
                    Picker("Tür", selection: $draft.type) {
                        ForEach(TransactionType.allCases) { type in
                            Text(type.title).tag(type)
                        }
                    }
                    .pickerStyle(.segmented)
                }

                Section("Renk") {
                    LazyVGrid(columns: colorColumns, spacing: 10) {
                        ForEach(CategoryPalette.colors, id: \.self) { hex in
                            let isSelected = draft.colorHex.caseInsensitiveCompare(hex) == .orderedSame
                            Button {
                                draft.colorHex = hex
                            } label: {
                                Circle()
                                    .fill(Color(hex: hex))
                                    .frame(width: 34, height: 34)
                                    .overlay {
                                        if isSelected {
                                            Image(systemName: "checkmark")
                                                .font(.footnote.weight(.bold))
                                                .foregroundStyle(.white)
                                        }
                                    }
                                    .overlay(
                                        Circle()
                                            .stroke(Color.primary.opacity(isSelected ? 0.4 : 0), lineWidth: 2)
                                            .padding(-3)
                                    )
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel("Renk seçeneği")
                            .accessibilityAddTraits(isSelected ? [.isSelected, .isButton] : .isButton)
                        }
                    }
                    .padding(.vertical, 4)
                }

                Section("Simge") {
                    LazyVGrid(columns: iconColumns, spacing: 10) {
                        ForEach(CategoryPalette.icons, id: \.self) { icon in
                            let isSelected = draft.iconName == icon
                            Button {
                                draft.iconName = icon
                            } label: {
                                Image(systemName: icon)
                                    .font(.system(size: 18))
                                    .foregroundStyle(isSelected ? Color(hex: draft.colorHex) : .secondary)
                                    .frame(width: 42, height: 42)
                                    .background(
                                        RoundedRectangle(cornerRadius: 11, style: .continuous)
                                            .fill(isSelected ? Color(hex: draft.colorHex).opacity(0.16) : Color(.tertiarySystemFill))
                                    )
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel("Simge seçeneği")
                            .accessibilityAddTraits(isSelected ? [.isSelected, .isButton] : .isButton)
                        }
                    }
                    .padding(.vertical, 4)
                }

                if let errorMessage {
                    Section {
                        Text(errorMessage)
                            .font(.footnote)
                            .foregroundStyle(AppTheme.expense)
                    }
                }
            }
            .navigationTitle(isEditing ? "Kategoriyi Düzenle" : "Yeni Kategori")
            .navigationBarTitleDisplayMode(.inline)
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
        }
    }

    private func save() {
        guard draft.isValid else {
            errorMessage = L10n.text("Lütfen bir kategori adı girin.")
            return
        }
        if session.saveCategory(draft) {
            dismiss()
        } else {
            errorMessage = session.lastErrorMessage ?? "Kategori kaydedilemedi."
        }
    }
}
