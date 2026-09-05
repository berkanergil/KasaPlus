import Foundation

/// Para ve tarih biçimlendirme yardımcıları. Tüm biçimlendiriciler tek yerde
/// tutulur. Dil tercihi değiştiğinde yeni yerel ayarın hemen kullanılabilmesi için
/// tarih biçimlendiricileri ihtiyaç anında üretilir.
enum Formatters {
    static var locale: Locale { AppLanguage.current.locale }

    /// Tutarı, verilen para biriminin sembolüyle biçimlendirir. Örn. "₺1.250,00"
    static func money(_ amount: Double, currency: Currency, showsSign: Bool = false) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.locale = locale
        formatter.currencyCode = currency.code
        formatter.currencySymbol = currency.symbol
        formatter.maximumFractionDigits = 2
        formatter.minimumFractionDigits = 2

        let base = formatter.string(from: NSNumber(value: abs(amount))) ?? "\(currency.symbol)\(abs(amount))"
        guard showsSign else { return base }
        if amount > 0 { return "+" + base }
        if amount < 0 { return "−" + base }
        return base
    }

    /// Yüzde göstergesi. Örn. "%12,4"
    static func percent(_ value: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.locale = locale
        formatter.maximumFractionDigits = 1
        let number = formatter.string(from: NSNumber(value: abs(value))) ?? "0"
        return "%\(number)"
    }

    static var dayHeader: DateFormatter {
        let f = DateFormatter()
        f.locale = locale
        f.dateFormat = "d MMMM yyyy, EEEE"
        return f
    }

    static var shortDay: DateFormatter {
        let f = DateFormatter()
        f.locale = locale
        f.dateFormat = "d MMM"
        return f
    }

    static var monthYear: DateFormatter {
        let f = DateFormatter()
        f.locale = locale
        f.dateFormat = "MMMM yyyy"
        return f
    }

    static var monthShort: DateFormatter {
        let f = DateFormatter()
        f.locale = locale
        f.dateFormat = "MMM"
        return f
    }

    static var weekdayShort: DateFormatter {
        let f = DateFormatter()
        f.locale = locale
        f.dateFormat = "EEE"
        return f
    }

    static var year: DateFormatter {
        let f = DateFormatter()
        f.locale = locale
        f.dateFormat = "yyyy"
        return f
    }

    static var dateTime: DateFormatter {
        let f = DateFormatter()
        f.locale = locale
        f.dateStyle = .medium
        f.timeStyle = .short
        return f
    }

    /// "Bugün" / "Dün" gibi göreli gün başlıkları.
    static func relativeDayTitle(for date: Date, calendar: Calendar = .turkish) -> String {
        if calendar.isDateInToday(date) { return L10n.text("Bugün") }
        if calendar.isDateInYesterday(date) { return L10n.text("Dün") }
        return dayHeader.string(from: date)
    }
}
