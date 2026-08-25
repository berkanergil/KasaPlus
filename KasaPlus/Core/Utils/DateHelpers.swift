import Foundation

extension Calendar {
    /// Haftanın pazartesi başladığı Türkiye takvimi.
    static var turkish: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.locale = Locale(identifier: "tr_TR")
        calendar.firstWeekday = 2 // Pazartesi
        return calendar
    }
}

extension Date {
    func startOfDay(_ calendar: Calendar = .turkish) -> Date {
        calendar.startOfDay(for: self)
    }

    func endOfDay(_ calendar: Calendar = .turkish) -> Date {
        calendar.date(byAdding: DateComponents(day: 1, second: -1), to: startOfDay(calendar)) ?? self
    }

    func startOfMonth(_ calendar: Calendar = .turkish) -> Date {
        calendar.date(from: calendar.dateComponents([.year, .month], from: self)) ?? self
    }

    func startOfYear(_ calendar: Calendar = .turkish) -> Date {
        calendar.date(from: calendar.dateComponents([.year], from: self)) ?? self
    }

    func adding(_ component: Calendar.Component, _ value: Int, _ calendar: Calendar = .turkish) -> Date {
        calendar.date(byAdding: component, value: value, to: self) ?? self
    }
}

/// Dashboard ve raporlarda kullanılan dönem seçimi.
enum ReportPeriod: String, CaseIterable, Identifiable, Sendable {
    case week
    case month
    case year

    var id: String { rawValue }

    var title: String {
        switch self {
        case .week: return "Hafta"
        case .month: return "Ay"
        case .year: return "Yıl"
        }
    }

    /// Bu dönemin bir birim öncesi/sonrası için takvim bileşeni.
    var calendarComponent: Calendar.Component {
        switch self {
        case .week: return .weekOfYear
        case .month: return .month
        case .year: return .year
        }
    }
}

/// Bir raporun kapsadığı kapalı tarih aralığı ve insan okunur başlığı.
struct PeriodRange: Equatable, Sendable {
    let start: Date
    let end: Date
    let title: String

    func contains(_ date: Date) -> Bool {
        date >= start && date <= end
    }

    /// Seçili dönem ve ofset için (0 = bu dönem, -1 = bir önceki dönem) aralık üretir.
    static func make(period: ReportPeriod, offset: Int, reference: Date = .now, calendar: Calendar = .turkish) -> PeriodRange {
        switch period {
        case .week:
            let anchor = calendar.date(byAdding: .weekOfYear, value: offset, to: reference) ?? reference
            let comps = calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: anchor)
            let start = (calendar.date(from: comps) ?? anchor).startOfDay(calendar)
            let end = start.adding(.day, 6, calendar).endOfDay(calendar)
            let title = "\(Formatters.shortDay.string(from: start)) – \(Formatters.shortDay.string(from: end))"
            return PeriodRange(start: start, end: end, title: title)

        case .month:
            let anchor = calendar.date(byAdding: .month, value: offset, to: reference) ?? reference
            let start = anchor.startOfMonth(calendar)
            let end = start.adding(.month, 1, calendar).adding(.day, -1, calendar).endOfDay(calendar)
            return PeriodRange(start: start, end: end, title: Formatters.monthYear.string(from: start).capitalizedFirst)

        case .year:
            let anchor = calendar.date(byAdding: .year, value: offset, to: reference) ?? reference
            let start = anchor.startOfYear(calendar)
            let end = start.adding(.year, 1, calendar).adding(.day, -1, calendar).endOfDay(calendar)
            return PeriodRange(start: start, end: end, title: Formatters.year.string(from: start))
        }
    }

    /// Bu aralığın bir önceki dönemdeki karşılığı (karşılaştırma için).
    func previous(period: ReportPeriod, offset: Int, reference: Date = .now) -> PeriodRange {
        PeriodRange.make(period: period, offset: offset - 1, reference: reference)
    }
}

extension String {
    var capitalizedFirst: String {
        guard let first else { return self }
        return String(first).uppercased(with: Locale(identifier: "tr_TR")) + dropFirst()
    }
}
