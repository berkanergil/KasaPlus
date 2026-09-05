import Foundation
import Observation

/// Bir günlük kur anlık görüntüsü. Oranlar "1 EUR = X birim" biçiminde tutulur;
/// herhangi iki para birimi arasındaki çapraz kur bundan hesaplanır.
struct ExchangeRateSnapshot: Codable, Equatable, Sendable {
    /// Anahtar: para birimi kodu, değer: 1 EUR karşılığı
    var ratesPerEUR: [String: Double]
    var fetchedAt: Date
    /// Kur sağlayıcısının yayımladığı tarih (hafta sonu/tatilde bir önceki iş günü olabilir)
    var effectiveDate: Date?

    /// Hiç kur çekilmemişken kullanılan yaklaşık değerler.
    /// Yalnızca ilk açılışta ve internet yokken devreye girer; kullanıcıya
    /// "kur güncel değil" uyarısı gösterilir.
    static let placeholder = ExchangeRateSnapshot(
        ratesPerEUR: ["EUR": 1.0, "TRY": 47.0, "USD": 1.09, "GBP": 0.85],
        fetchedAt: Date(timeIntervalSince1970: 0),
        effectiveDate: nil
    )

    var isPlaceholder: Bool { fetchedAt == Date(timeIntervalSince1970: 0) }

    func rate(from source: Currency, to target: Currency) -> Double? {
        guard let sourcePerEUR = ratesPerEUR[source.code],
              let targetPerEUR = ratesPerEUR[target.code],
              sourcePerEUR > 0 else { return nil }
        return targetPerEUR / sourcePerEUR
    }
}

/// Ücretsiz kur servisi (frankfurter.app — ECB verisi, API anahtarı gerektirmez).
/// Kur günde bir kez çekilir ve diskte cache'lenir (PRD 5.1.1).
@MainActor
@Observable
final class ExchangeRateService {

    private(set) var snapshot: ExchangeRateSnapshot
    private(set) var isRefreshing = false
    private(set) var lastErrorMessage: String?

    @ObservationIgnored private let session: URLSession
    @ObservationIgnored private let cacheURL: URL
    @ObservationIgnored private let calendar = Calendar.turkish

    init(session: URLSession = .shared) {
        self.session = session

        let directory = (try? FileManager.default.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )) ?? URL.temporaryDirectory
        self.cacheURL = directory.appendingPathComponent("exchange-rates.json")

        if let data = try? Data(contentsOf: cacheURL),
           let cached = try? JSONDecoder().decode(ExchangeRateSnapshot.self, from: data) {
            self.snapshot = cached
        } else {
            self.snapshot = .placeholder
        }
    }

    /// Kur bugün çekilmişse ağa çıkmaz.
    var needsRefresh: Bool {
        if snapshot.isPlaceholder { return true }
        return !calendar.isDateInToday(snapshot.fetchedAt)
    }

    var statusDescription: String {
        if snapshot.isPlaceholder { return L10n.text("Kur henüz güncellenmedi") }
        return L10n.format("Son güncelleme: %@", Formatters.dateTime.string(from: snapshot.fetchedAt))
    }

    func refreshIfNeeded() async {
        guard needsRefresh else { return }
        await refresh()
    }

    func refresh() async {
        guard !isRefreshing else { return }
        isRefreshing = true
        lastErrorMessage = nil
        defer { isRefreshing = false }

        let symbols = Currency.allCases
            .map(\.code)
            .filter { $0 != "EUR" }
            .joined(separator: ",")

        var components = URLComponents(string: "https://api.frankfurter.app/latest")
        components?.queryItems = [
            URLQueryItem(name: "from", value: "EUR"),
            URLQueryItem(name: "to", value: symbols)
        ]
        guard let url = components?.url else { return }

        do {
            var request = URLRequest(url: url)
            request.timeoutInterval = 15
            let (data, response) = try await session.data(for: request)
            guard let http = response as? HTTPURLResponse, (200 ..< 300).contains(http.statusCode) else {
                throw URLError(.badServerResponse)
            }

            let payload = try JSONDecoder().decode(FrankfurterResponse.self, from: data)
            var rates = payload.rates
            rates["EUR"] = 1.0

            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "yyyy-MM-dd"
            dateFormatter.locale = Locale(identifier: "en_US_POSIX")

            let newSnapshot = ExchangeRateSnapshot(
                ratesPerEUR: rates,
                fetchedAt: Date(),
                effectiveDate: dateFormatter.date(from: payload.date)
            )
            snapshot = newSnapshot
            persist(newSnapshot)
        } catch {
            // Ağ yoksa mevcut cache kullanılmaya devam eder — uygulama çalışmayı sürdürür.
            lastErrorMessage = L10n.text("Kur bilgisi güncellenemedi. Son bilinen kur kullanılıyor.")
        }
    }

    private func persist(_ snapshot: ExchangeRateSnapshot) {
        guard let data = try? JSONEncoder().encode(snapshot) else { return }
        try? data.write(to: cacheURL, options: .atomic)
    }

    private struct FrankfurterResponse: Decodable {
        let amount: Double
        let base: String
        let date: String
        let rates: [String: Double]
    }
}
