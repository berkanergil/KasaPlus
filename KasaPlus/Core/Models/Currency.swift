import Foundation

/// Desteklenen para birimleri. Genişletilebilir: yeni bir case eklemek yeterlidir.
enum Currency: String, CaseIterable, Codable, Identifiable, Sendable {
    case TRY
    case USD
    case EUR
    case GBP

    var id: String { rawValue }

    var code: String { rawValue }

    var symbol: String {
        switch self {
        case .TRY: return "₺"
        case .USD: return "$"
        case .EUR: return "€"
        case .GBP: return "£"
        }
    }

    var title: String {
        switch self {
        case .TRY: return L10n.text("Türk Lirası")
        case .USD: return L10n.text("ABD Doları")
        case .EUR: return L10n.text("Euro")
        case .GBP: return L10n.text("İngiliz Sterlini")
        }
    }

    var displayName: String { "\(symbol) \(code)" }

    static func from(rawValue: String) -> Currency {
        Currency(rawValue: rawValue) ?? .TRY
    }
}
