import SwiftUI

/// İşlemin türü: gelir veya gider.
/// SwiftData'da `rawValue` (String) olarak saklanır; yeni tür eklemek geriye dönük uyumludur.
enum TransactionType: String, CaseIterable, Codable, Identifiable, Sendable {
    case income
    case expense

    var id: String { rawValue }

    var title: String {
        switch self {
        case .income: return "Gelir"
        case .expense: return "Gider"
        }
    }

    var systemImage: String {
        switch self {
        case .income: return "arrow.down.circle.fill"
        case .expense: return "arrow.up.circle.fill"
        }
    }

    var tintColor: Color {
        switch self {
        case .income: return AppTheme.income
        case .expense: return AppTheme.expense
        }
    }

    /// Tutarın bakiyeye etkisi (+1 gelir, -1 gider).
    var signMultiplier: Double {
        self == .income ? 1 : -1
    }
}
