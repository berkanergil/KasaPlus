import SwiftUI

/// Kategori listesi: hazır ve kullanıcı tanımlı kategoriler (PRD 5.2).
/// Düzenle modunda satırlar sürüklenerek sıralanabilir ve silinebilir.
struct CategoryManagementView: View {

    @Environment(AppSession.self) private var session
    @Environment(\.dismiss) private var dismiss

    @State private var editorRequest: CategoryEditorRequest?
    @State private var pendingDeletion: Category?
    @State private var deletionWarning: String = ""
    @State private var editMode: EditMode = .inactive

    var body: some View {
        NavigationStack {
            List {
                ForEach(TransactionType.allCases) { type in
                    section(for: type)
                }

                Section {
                    Text("Sırayı değiştirmek için Düzenle'ye dokunup satırları sürükleyin. Bu sıra, kayıt ekranındaki kategori seçiminde de geçerlidir.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .environment(\.editMode, $editMode)
            .navigationTitle("Kategoriler")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Kapat") { dismiss() }
                }
                ToolbarItemGroup(placement: .primaryAction) {
                    if !session.categories.isEmpty {
                        Button(editMode == .active ? "Bitti" : "Düzenle") {
                            withAnimation { editMode = editMode == .active ? .inactive : .active }
                        }
                    }
                    Menu {
                        Button {
                            editorRequest = CategoryEditorRequest(draft: .empty(type: .expense))
                        } label: {
                            Label("Gider kategorisi", systemImage: TransactionType.expense.systemImage)
                        }
                        Button {
                            editorRequest = CategoryEditorRequest(draft: .empty(type: .income))
                        } label: {
                            Label("Gelir kategorisi", systemImage: TransactionType.income.systemImage)
                        }
                    } label: {
                        Image(systemName: "plus")
                    }
                    .accessibilityLabel("Yeni kategori")
                }
            }
            .sheet(item: $editorRequest) { request in
                CategoryEditorView(draft: request.draft)
            }
            .confirmationDialog(
                "Kategoriyi sil",
                isPresented: Binding(
                    get: { pendingDeletion != nil },
                    set: { if !$0 { pendingDeletion = nil } }
                ),
                titleVisibility: .visible
            ) {
                Button("Sil", role: .destructive) {
                    if let pendingDeletion {
                        session.deleteCategory(id: pendingDeletion.id)
                    }
                    pendingDeletion = nil
                }
                Button("Vazgeç", role: .cancel) { pendingDeletion = nil }
            } message: {
                Text(deletionWarning)
            }
        }
    }

    // MARK: - Bölüm

    @ViewBuilder
    private func section(for type: TransactionType) -> some View {
        let categories = session.categories(for: type)

        Section {
            if categories.isEmpty {
                Text("Bu tür için kategori yok.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(categories) { category in
                    Button {
                        editorRequest = CategoryEditorRequest(draft: CategoryDraft(category: category))
                    } label: {
                        row(for: category)
                    }
                    .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                        Button(role: .destructive) {
                            prepareDeletion(of: category)
                        } label: {
                            Label("Sil", systemImage: "trash")
                        }
                    }
                }
                .onMove { source, destination in
                    move(in: type, from: source, to: destination)
                }
                .onDelete { offsets in
                    deleteAt(in: type, offsets: offsets)
                }
            }
        } header: {
            Label(
                type == .income ? "Gelir Kategorileri" : "Gider Kategorileri",
                systemImage: type.systemImage
            )
            .font(.caption)
            .textCase(nil)
        }
    }

    private func row(for category: Category) -> some View {
        HStack(spacing: 12) {
            CategoryIconBadge(
                iconName: category.iconName,
                colorHex: category.colorHex,
                size: 34
            )
            VStack(alignment: .leading, spacing: 2) {
                Text(category.name)
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                let count = session.transactionCount(categoryID: category.id)
                Text(
                    [
                        category.isDefault ? "Hazır kategori" : nil,
                        count == 0 ? "Kayıt yok" : "\(count) işlem"
                    ]
                    .compactMap { $0 }
                    .joined(separator: " · ")
                )
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

    // MARK: - Eylemler

    private func move(in type: TransactionType, from source: IndexSet, to destination: Int) {
        var ordered = session.categories(for: type)
        ordered.move(fromOffsets: source, toOffset: destination)
        session.reorderCategories(ids: ordered.map(\.id))
    }

    private func deleteAt(in type: TransactionType, offsets: IndexSet) {
        let categories = session.categories(for: type)
        guard let index = offsets.first, categories.indices.contains(index) else { return }
        prepareDeletion(of: categories[index])
    }

    private func prepareDeletion(of category: Category) {
        let count = session.transactionCount(categoryID: category.id)
        deletionWarning = count > 0
            ? "\"\(category.name)\" kategorisine bağlı \(count) işlem var. Kategori silinse de işlemleriniz korunur; listede \"Silinmiş kategori\" olarak görünür."
            : "\"\(category.name)\" kategorisi silinecek."
        pendingDeletion = category
    }
}

/// `sheet(item:)` sunumu için taslağı saran kimlikli kap.
/// (CategoryDraft'ın kendi `id` alanı "düzenlenen kategori" anlamına geldiği için
/// doğrudan Identifiable yapılmaz.)
struct CategoryEditorRequest: Identifiable {
    let id = UUID()
    var draft: CategoryDraft
}
