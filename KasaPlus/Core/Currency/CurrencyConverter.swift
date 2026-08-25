import Foundation

/// İşlemleri raporlarda ortak "ana para birimi"ne çeviren yardımcı (PRD 5.1.1).
struct CurrencyConverter {
    let snapshot: ExchangeRateSnapshot
    let mainCurrency: Currency

    /// Kur bulunamazsa `nil` döner — arayüz bu durumu "kur yok" olarak gösterir.
    func convert(_ amount: Double, from source: Currency) -> Double? {
        if source == mainCurrency { return amount }
        guard let rate = snapshot.rate(from: source, to: mainCurrency) else { return nil }
        return amount * rate
    }

    /// Raporlarda kullanılan güvenli sürüm: kur yoksa orijinal tutar aynen kabul edilir
    /// (toplamın tamamen kaybolmaması için) ve `hasMissingRate` ile işaretlenir.
    func convertForReporting(_ amount: Double, from source: Currency) -> (value: Double, converted: Bool) {
        if source == mainCurrency { return (amount, true) }
        guard let rate = snapshot.rate(from: source, to: mainCurrency) else { return (amount, false) }
        return (amount * rate, true)
    }

    func convert(_ transaction: FinanceTransaction) -> Double? {
        convert(transaction.amount, from: transaction.currency)
    }

    /// İşlem listesinde ikincil satır olarak gösterilen "≈ ₺X" metni.
    func secondaryAmountText(for transaction: FinanceTransaction) -> String? {
        guard transaction.currency != mainCurrency,
              let converted = convert(transaction.amount, from: transaction.currency) else { return nil }
        return "≈ " + Formatters.money(converted, currency: mainCurrency)
    }

    var isUsingStaleRates: Bool { snapshot.isPlaceholder }
}
