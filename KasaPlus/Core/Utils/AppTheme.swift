import SwiftUI

/// Uygulama genelinde kullanılan renkler ve ölçüler.
/// Renkler Asset Catalog üzerinden gelir; böylece Dark Mode otomatik desteklenir.
enum AppTheme {
    static let income = Color("IncomeColor")
    static let expense = Color("ExpenseColor")
    static let accent = Color("AccentColor")

    static let cardCornerRadius: CGFloat = 16
    static let cardPadding: CGFloat = 16
}

/// Kullanıcının seçtiği görünüm tercihi.
enum AppearanceMode: String, CaseIterable, Identifiable, Codable, Sendable {
    case system
    case light
    case dark

    var id: String { rawValue }

    var title: String {
        switch self {
        case .system: return "Sistem"
        case .light: return "Aydınlık"
        case .dark: return "Karanlık"
        }
    }

    var colorScheme: ColorScheme? {
        switch self {
        case .system: return nil
        case .light: return .light
        case .dark: return .dark
        }
    }
}

// MARK: - Hex renk desteği (kullanıcı tanımlı kategoriler için)

extension Color {
    /// "#RRGGBB" veya "RRGGBB" biçimindeki bir hex değerinden renk üretir.
    init(hex: String) {
        let cleaned = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var value: UInt64 = 0
        Scanner(string: cleaned).scanHexInt64(&value)

        let r, g, b, a: Double
        switch cleaned.count {
        case 6:
            r = Double((value & 0xFF0000) >> 16) / 255
            g = Double((value & 0x00FF00) >> 8) / 255
            b = Double(value & 0x0000FF) / 255
            a = 1
        case 8:
            r = Double((value & 0xFF000000) >> 24) / 255
            g = Double((value & 0x00FF0000) >> 16) / 255
            b = Double((value & 0x0000FF00) >> 8) / 255
            a = Double(value & 0x000000FF) / 255
        default:
            r = 0.5; g = 0.5; b = 0.5; a = 1
        }
        self.init(.sRGB, red: r, green: g, blue: b, opacity: a)
    }
}

/// Kategori düzenleme ekranında sunulan hazır renk paleti.
enum CategoryPalette {
    static let colors: [String] = [
        "#E5484D", "#F76808", "#FFB224", "#46A758",
        "#12A594", "#0091FF", "#3E63DD", "#8E4EC6",
        "#D6409F", "#A18072", "#889096", "#30A46C"
    ]

    static let icons: [String] = [
        "pills.fill", "cross.case.fill", "bandage.fill", "stethoscope",
        "house.fill", "bolt.fill", "drop.fill", "flame.fill",
        "person.2.fill", "doc.text.fill", "shippingbox.fill", "cart.fill",
        "bag.fill", "creditcard.fill", "banknote.fill", "building.columns.fill",
        "wrench.and.screwdriver.fill", "car.fill", "phone.fill", "wifi",
        "gift.fill", "star.fill", "tag.fill", "ellipsis.circle.fill"
    ]
}
