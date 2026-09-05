import SwiftUI

// MARK: - Kategori yönetimi kısayolu

/// Kategori yönetimini (`CategoryManagementView`) açan küçük düzenleme butonu.
/// Kategorilerin geçtiği her bölümde kullanılır; böylece kullanıcı kategori
/// eklemek veya düzenlemek için Ayarlar'a gitmek zorunda kalmaz.
struct CategoryManagerButton: View {

    /// Dar alanlarda yalnızca simge gösterilir.
    var showsTitle: Bool = true

    @State private var isManagerPresented = false

    var body: some View {
        Button {
            isManagerPresented = true
        } label: {
            if showsTitle {
                Label("Düzenle", systemImage: "slider.horizontal.3")
                    .font(.caption.weight(.semibold))
            } else {
                Image(systemName: "slider.horizontal.3")
                    .font(.caption.weight(.semibold))
            }
        }
        .buttonStyle(.plain)
        .foregroundStyle(Color.accentColor)
        .textCase(nil)
        .accessibilityLabel("Kategorileri düzenle")
        .sheet(isPresented: $isManagerPresented) {
            CategoryManagementView()
        }
    }
}

/// Form bölümleri için başlık: solda başlık, sağda kategori düzenleme butonu.
struct CategorySectionHeader: View {

    var title: LocalizedStringKey = "Kategori"

    var body: some View {
        HStack {
            Text(title)
            Spacer()
            CategoryManagerButton()
        }
    }
}

/// Kategori listesi boşken gösterilen, dokunulduğunda kategori yönetimini
/// açan satır. Kullanıcıyı "Ayarlar > Kategoriler" metniyle yönlendirmek
/// yerine doğrudan oraya götürür.
struct CategoryEmptyRow: View {

    let message: LocalizedStringKey

    @State private var isManagerPresented = false

    var body: some View {
        Button {
            isManagerPresented = true
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "plus.circle")
                Text(message)
                Spacer(minLength: 8)
                Image(systemName: "chevron.right")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.tertiary)
            }
            .font(.footnote)
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .foregroundStyle(Color.accentColor)
        .sheet(isPresented: $isManagerPresented) {
            CategoryManagementView()
        }
    }
}
