import Foundation
import Observation

enum AppLanguage: String, CaseIterable, Identifiable, Hashable, Sendable {
    case system
    case turkish
    case english

    static let defaultsKey = "settings.language"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .system: return L10n.text("Sistem dili")
        case .turkish: return L10n.text("Türkçe")
        case .english: return "English"
        }
    }

    var locale: Locale {
        switch self {
        case .system: return .autoupdatingCurrent
        case .turkish: return Locale(identifier: "tr_TR")
        case .english: return Locale(identifier: "en_US")
        }
    }

    static var current: AppLanguage {
        AppLanguage(rawValue: UserDefaults.standard.string(forKey: defaultsKey) ?? "") ?? .system
    }
}

/// Uygulama diline göre metin ve biçimlendirilmiş metin döndürür.
/// SwiftUI'nin `Text("…")` gibi yerleşik yerelleştirmesi dışında, model ve
/// servis katmanlarında üretilen `String` değerleri de bu yardımcı üzerinden
/// çevrilir.
enum L10n {
    static func text(_ key: String) -> String {
        guard AppLanguage.current.locale.language.languageCode?.identifier == "en",
              let path = Bundle.main.path(forResource: "en", ofType: "lproj"),
              let bundle = Bundle(path: path)
        else {
            return key
        }
        return bundle.localizedString(forKey: key, value: key, table: "Localizable")
    }

    static func format(_ key: String, _ arguments: CVarArg...) -> String {
        String(format: text(key), locale: AppLanguage.current.locale, arguments: arguments)
    }
}

/// Kullanıcı tercihleri. Hassas olmayan ayarlar burada (UserDefaults) tutulur;
/// oturum bilgileri Keychain'dedir.
///
/// Not: `@Observable` makrosu depolanan özelliklere kendi erişimcilerini eklediği
/// için `didSet` kullanılamaz. Bunun yerine her ayar, izlenen özel bir depo
/// üzerinden hesaplanan özellik olarak açılır; yazma anında UserDefaults'a işlenir.
@MainActor
@Observable
final class AppSettings {

    /// Raporlarda ve toplamlarda esas alınan para birimi (PRD 5.1.1 / 5.5).
    var mainCurrency: Currency {
        get { storedMainCurrency }
        set {
            storedMainCurrency = newValue
            defaults.set(newValue.rawValue, forKey: Keys.mainCurrency)
        }
    }

    /// Yeni işlem eklerken varsayılan olarak seçili gelen para birimi.
    var defaultEntryCurrency: Currency {
        get { storedDefaultEntryCurrency }
        set {
            storedDefaultEntryCurrency = newValue
            defaults.set(newValue.rawValue, forKey: Keys.defaultEntryCurrency)
        }
    }

    var appearance: AppearanceMode {
        get { storedAppearance }
        set {
            storedAppearance = newValue
            defaults.set(newValue.rawValue, forKey: Keys.appearance)
        }
    }

    /// Uygulamanın tarih, sayı ve sistem bileşenlerinde kullanılacak dil/yerel ayarı.
    var language: AppLanguage {
        get { storedLanguage }
        set {
            storedLanguage = newValue
            defaults.set(newValue.rawValue, forKey: AppLanguage.defaultsKey)
        }
    }

    // İzlenen (observed) depolar — doğrudan kullanılmaz.
    private var storedMainCurrency: Currency
    private var storedDefaultEntryCurrency: Currency
    private var storedAppearance: AppearanceMode
    private var storedLanguage: AppLanguage

    @ObservationIgnored private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        self.storedMainCurrency = Currency.from(
            rawValue: defaults.string(forKey: Keys.mainCurrency) ?? Currency.TRY.rawValue
        )
        self.storedDefaultEntryCurrency = Currency.from(
            rawValue: defaults.string(forKey: Keys.defaultEntryCurrency) ?? Currency.TRY.rawValue
        )
        self.storedAppearance = AppearanceMode(
            rawValue: defaults.string(forKey: Keys.appearance) ?? ""
        ) ?? .system
        self.storedLanguage = AppLanguage(
            rawValue: defaults.string(forKey: AppLanguage.defaultsKey) ?? ""
        ) ?? .system
    }

    private enum Keys {
        static let mainCurrency = "settings.mainCurrency"
        static let defaultEntryCurrency = "settings.defaultEntryCurrency"
        static let appearance = "settings.appearance"
    }
}
