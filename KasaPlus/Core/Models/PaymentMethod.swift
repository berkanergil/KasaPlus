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
        case .cash: return "Nakit"
        case .creditCard: return "Kredi Kartı"
        case .debitCard: return "Banka Kartı"
        case .bankTransfer: return "Banka Transferi"
        case .check: return "Çek"
        }
    }

    /// Ayarlar / filtre gibi dar alanlarda kullanılan kısa ad.
    var shortTitle: String {
        switch self {
        case .cash: return "Nakit"
        case .creditCard: return "Kredi K."
        case .debitCard: return "Banka K."
        case .bankTransfer: return "Havale"
        case .check: return "Çek"
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
