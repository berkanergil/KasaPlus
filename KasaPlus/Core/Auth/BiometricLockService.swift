import Foundation
import LocalAuthentication
import Observation

/// Uygulama içi kilit (PRD 4): her açılışta ve arka plandan dönüşte
/// Face ID / Touch ID ile doğrulama. Başarısız olursa cihaz parolası fallback'i kullanılır.
@MainActor
@Observable
final class BiometricLockService {

    /// Kilit ekranı gösteriliyor mu?
    private(set) var isLocked: Bool = false
    private(set) var lastErrorMessage: String?
    private(set) var isAuthenticating: Bool = false

    /// Kullanıcının ayarlardan açıp kapatabildiği tercih.
    ///
    /// Not: `@Observable` makrosu depolanan özelliklere kendi erişimcilerini eklediği
    /// için `didSet` kullanılamaz; tercih izlenen özel bir depo üzerinden yazılır.
    var isEnabled: Bool {
        get { storedIsEnabled }
        set {
            storedIsEnabled = newValue
            defaults.set(newValue, forKey: Self.enabledKey)
            if !newValue { isLocked = false }
        }
    }

    private var storedIsEnabled: Bool

    @ObservationIgnored private let defaults: UserDefaults
    @ObservationIgnored private static let enabledKey = "security.biometricLockEnabled"
    /// Arka planda bu süreden uzun kalınırsa yeniden kilitlenir.
    @ObservationIgnored private let graceInterval: TimeInterval = 15
    @ObservationIgnored private var backgroundedAt: Date?

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        self.storedIsEnabled = defaults.bool(forKey: Self.enabledKey)
    }

    /// Cihazda hangi biyometri var?
    var biometryDescription: String {
        let context = LAContext()
        var error: NSError?
        guard context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) else {
            return L10n.text("Cihaz Parolası")
        }
        switch context.biometryType {
        case .faceID: return "Face ID"
        case .touchID: return "Touch ID"
        case .opticID: return "Optic ID"
        default: return L10n.text("Cihaz Parolası")
        }
    }

    var isBiometryAvailable: Bool {
        var error: NSError?
        return LAContext().canEvaluatePolicy(.deviceOwnerAuthentication, error: &error)
    }

    // MARK: - Yaşam döngüsü kancaları

    func applicationDidLaunch() {
        if isEnabled { isLocked = true }
    }

    func applicationWillResignActive() {
        backgroundedAt = Date()
    }

    func applicationDidBecomeActive() {
        guard isEnabled, !isLocked else { return }
        guard let backgroundedAt else { return }
        if Date().timeIntervalSince(backgroundedAt) > graceInterval {
            isLocked = true
        }
        self.backgroundedAt = nil
    }

    // MARK: - Doğrulama

    func unlock() async {
        guard isEnabled, isLocked, !isAuthenticating else { return }
        isAuthenticating = true
        lastErrorMessage = nil
        defer { isAuthenticating = false }

        let context = LAContext()
        context.localizedCancelTitle = L10n.text("İptal")
        context.localizedFallbackTitle = L10n.text("Cihaz Parolasını Kullan")

        do {
            // `.deviceOwnerAuthentication` biyometri başarısız olursa
            // otomatik olarak cihaz parolasına düşer.
            let success = try await context.evaluatePolicy(
                .deviceOwnerAuthentication,
                localizedReason: L10n.text("Kasa+ verilerinize erişmek için kimliğinizi doğrulayın.")
            )
            if success { isLocked = false }
        } catch let error as LAError where error.code == .userCancel || error.code == .appCancel {
            lastErrorMessage = nil
        } catch {
            lastErrorMessage = L10n.text("Doğrulama başarısız. Tekrar deneyin.")
        }
    }

    /// Ayarlar ekranından kilidi açarken önce kimlik doğrulaması istenir.
    @discardableResult
    func setEnabled(_ newValue: Bool) async -> Bool {
        guard newValue else {
            isEnabled = false
            return true
        }
        let context = LAContext()
        context.localizedCancelTitle = L10n.text("İptal")
        do {
            let success = try await context.evaluatePolicy(
                .deviceOwnerAuthentication,
                localizedReason: L10n.text("Uygulama kilidini etkinleştirmek için kimliğinizi doğrulayın.")
            )
            isEnabled = success
            return success
        } catch {
            lastErrorMessage = L10n.text("Doğrulama başarısız. Tekrar deneyin.")
            return false
        }
    }
}
