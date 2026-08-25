import Foundation

/// Bir dönemin gelir / gider / net özeti. Tüm tutarlar ana para birimine çevrilmiştir.
struct PeriodSummary: Equatable, Sendable {
    var income: Double = 0
    var expense: Double = 0
    var transactionCount: Int = 0
    /// Kur bulunamadığı için çevrilemeden toplanan işlem oldu mu?
    var hasUnconvertedAmounts: Bool = false

    var net: Double { income - expense }
    var isEmpty: Bool { transactionCount == 0 }

    /// Gelire göre gider oranı (0…1+). Gelir yoksa nil.
    var expenseRatio: Double? {
        guard income > 0 else { return nil }
        return expense / income
    }
}

/// Kategori dağılım grafiğinin tek dilimi.
struct CategoryBreakdownItem: Identifiable, Equatable, Sendable {
    let id: UUID
    let name: String
    let iconName: String
    let colorHex: String
    let total: Double
    let transactionCount: Int
    /// 0…1 arası pay
    let share: Double
}

/// Trend grafiğinin tek noktası.
struct TrendPoint: Identifiable, Equatable, Sendable {
    let id: Date
    let date: Date
    let label: String
    let income: Double
    let expense: Double

    var net: Double { income - expense }
}

/// İki dönemin karşılaştırması (bu ay ↔ geçen ay gibi).
struct PeriodComparison: Equatable, Sendable {
    let current: PeriodSummary
    let previous: PeriodSummary
    let currentTitle: String
    let previousTitle: String

    /// Yüzde değişim. Önceki dönem sıfırsa nil (oran tanımsız).
    private func change(_ currentValue: Double, _ previousValue: Double) -> Double? {
        guard previousValue != 0 else { return nil }
        return (currentValue - previousValue) / abs(previousValue) * 100
    }

    var incomeChange: Double? { change(current.income, previous.income) }
    var expenseChange: Double? { change(current.expense, previous.expense) }
    var netChange: Double? { change(current.net, previous.net) }
}
