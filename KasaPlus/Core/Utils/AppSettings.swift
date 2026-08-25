import Foundation
import Observation

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

    // İzlenen (observed) depolar — doğrudan kullanılmaz.
    private var storedMainCurrency: Currency
    private var storedDefaultEntryCurrency: Currency
    private var storedAppearance: AppearanceMode

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
    }

    private enum Keys {
        static let mainCurrency = "settings.mainCurrency"
        static let defaultEntryCurrency = "settings.defaultEntryCurrency"
        static let appearance = "settings.appearance"
    }
}
