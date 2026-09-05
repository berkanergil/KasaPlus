import Foundation

/// Ödeme yöntemi. Yeni yöntem eklemek için buraya bir case eklemek yeterlidir;
/// veritabanında `rawValue` saklandığı için mevcut kayıtlar bozulmaz.
enum PaymentMethod: String, CaseIterable, Codable, Identifiable, Sendable {
    case cash
    case creditCard
    case debitCard
    case bankTransfer
    case check

    var id: String { rawValue }

    var title: String {
        switch self {
        case .cash: return L10n.text("Nakit")
        case .creditCard: return L10n.text("Kredi Kartı")
        case .debitCard: return L10n.text("Banka Kartı")
        case .bankTransfer: return L10n.text("Banka Transferi")
        case .check: return L10n.text("Çek")
        }
    }

    /// Ayarlar / filtre gibi dar alanlarda kullanılan kısa ad.
    var shortTitle: String {
        switch self {
        case .cash: return L10n.text("Nakit")
        case .creditCard: return L10n.text("Kredi K.")
        case .debitCard: return L10n.text("Banka K.")
        case .bankTransfer: return L10n.text("Havale")
        case .check: return L10n.text("Çek")
        }
    }

    var systemImage: String {
        switch self {
        case .cash: return "banknote.fill"
        case .creditCard: return "creditcard.fill"
        case .debitCard: return "creditcard"
        case .bankTransfer: return "building.columns.fill"
        case .check: return "doc.text.fill"
        }
    }

    /// Nakit dışındaki tüm yöntemler bir bankaya bağlıdır; kayıt ekranında
    /// "Banka" seçimi yalnızca bu durumda gösterilir.
    var requiresBank: Bool { self != .cash }

    /// Bilinmeyen bir rawValue geldiğinde (ileri sürüm verisi) güvenli geri dönüş.
    static func from(rawValue: String) -> PaymentMethod {
        PaymentMethod(rawValue: rawValue) ?? .cash
    }
}
