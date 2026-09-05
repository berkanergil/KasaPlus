import SwiftUI

/// Banka listesi: ekleme, ad değiştirme, sürükleyerek sıralama ve silme.
struct BankManagementView: View {

    @Environment(AppSession.self) private var session
    @Environment(\.dismiss) private var dismiss

    @State private var editorRequest: BankEditorRequest?
    @State private var pendingDeletion: Bank?
    @State private var deletionWarning = ""
    @State private var editMode: EditMode = .inactive

    var body: some View {
        NavigationStack {
            List {
                Section {
                    if session.banks.isEmpty {
                        Text("Kayıtlı banka yok. Sağ üstteki + ile ekleyebilirsiniz.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(session.banks) { bank in
                            Button {
                                editorRequest = BankEditorRequest(draft: BankDraft(bank: bank))
                            } label: {
                                HStack(spacing: 12) {
                                    Text(bank.initials)
                                        .font(.caption.weight(.bold))
                                        .foregroundStyle(AppTheme.accent)
                                        .frame(width: 38, height: 38)
                                        .background(
                                            AppTheme.accent.opacity(0.14),
                                            in: RoundedRectangle(cornerRadius: 11, style: .continuous)
                                        )

                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(bank.name)
                                            .foregroundStyle(.primary)
                                            .lineLimit(1)
                                        let count = session.transactionCount(bankID: bank.id)
                                        Text(count == 0 ? "Kayıt yok" : "\(count) işlem")
                                            .font(.caption2)
                                            .foregroundStyle(.tertiary)
                                    }

                                    Spacer()

                                    if editMode == .inactive {
                                        Image(systemName: "chevron.right")
                                            .font(.caption)
                                            .foregroundStyle(.tertiary)
                                    }
                                }
                            }
                            .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                Button(role: .destructive) {
                                    prepareDeletion(of: bank)
                                } label: {
                                    Label("Sil", systemImage: "trash")
                                }
                            }
                        }
                        .onMove(perform: move)
                        .onDelete(perform: deleteAt)
                    }
                } header: {
                    Text("Bankalar")
                } footer: {
                    Text("Sırayı değiştirmek için Düzenle'ye dokunup satırları sürükleyin. Bu sıra, kayıt ekranındaki banka listesinde de geçerlidir.")
                }
            }
            .environment(\.editMode, $editMode)
            .navigationTitle("Banka Yönetimi")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Kapat") { dismiss() }
                }
                ToolbarItemGroup(placement: .primaryAction) {
                    if !session.banks.isEmpty {
                        Button(editMode == .active ? "Bitti" : "Düzenle") {
                            withAnimation { editMode = editMode == .active ? .inactive : .active }
                        }
                    }
                    Button {
                        editorRequest = BankEditorRequest(draft: .empty)
                    } label: {
                        Image(systemName: "plus")
                    }
                    .accessibilityLabel("Yeni banka")
                }
            }
            .sheet(item: $editorRequest) { request in
                BankEditorView(draft: request.draft)
            }
            .confirmationDialog(
                "Bankayı sil",
                isPresented: Binding(
                    get: { pendingDeletion != nil },
                    set: { if !$0 { pendingDeletion = nil } }
                ),
                titleVisibility: .visible
            ) {
                Button("Sil", role: .destructive) {
                    if let pendingDeletion { session.deleteBank(id: pendingDeletion.id) }
                    pendingDeletion = nil
                }
                Button("Vazgeç", role: .cancel) { pendingDeletion = nil }
            } message: {
                Text(deletionWarning)
            }
        }
    }

    // MARK: - Eylemler

    private func move(from source: IndexSet, to destination: Int) {
        var ordered = session.banks
        ordered.move(fromOffsets: source, toOffset: destination)
        session.reorderBanks(ids: ordered.map(\.id))
    }

    private func deleteAt(_ offsets: IndexSet) {
        guard let index = offsets.first else { return }
        prepareDeletion(of: session.banks[index])
    }

    private func prepareDeletion(of bank: Bank) {
        let count = session.transactionCount(bankID: bank.id)
        deletionWarning = count > 0
            ? L10n.format("%@ bankasına bağlı %lld işlem var. Banka silinse de işlemleriniz korunur; listede \"Silinmiş banka\" olarak görünür.", "\"\(bank.name)\"", count)
            : L10n.format("%@ silinecek.", "\"\(bank.name)\"")
        pendingDeletion = bank
    }
}

// MARK: - Banka ekleme / düzenleme

struct BankEditorView: View {

    @Environment(AppSession.self) private var session
    @Environment(\.dismiss) private var dismiss

    @State var draft: BankDraft
    @State private var errorMessage: String?
    @FocusState private var isNameFocused: Bool

    private var isEditing: Bool { draft.id != nil }

    var body: some View {
        NavigationStack {
            Form {
                Section("Banka adı") {
                    TextField("Örn. Garanti BBVA", text: $draft.name)
                        .textInputAutocapitalization(.words)
                        .focused($isNameFocused)
                }

                if let errorMessage {
                    Section {
                        Text(errorMessage)
                            .font(.footnote)
                            .foregroundStyle(AppTheme.expense)
                    }
                }
            }
            .navigationTitle(isEditing ? "Bankayı Düzenle" : "Yeni Banka")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Vazgeç") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Kaydet") {
                        if session.saveBank(draft) {
                            dismiss()
                        } else {
                            errorMessage = session.lastErrorMessage ?? "Banka kaydedilemedi."
                        }
                    }
                    .fontWeight(.semibold)
                    .disabled(!draft.isValid)
                }
            }
            .task { isNameFocused = true }
        }
        .presentationDetents([.medium])
    }
}

/// `sheet(item:)` için kimlikli kap.
struct BankEditorRequest: Identifiable {
    let id = UUID()
    var draft: BankDraft
}
