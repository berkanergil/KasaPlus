import Foundation
import AuthenticationServices
import CryptoKit
import Security
import Observation

/// Oturum açmış kullanıcı.
struct AuthenticatedUser: Equatable, Sendable {
    /// Uygulama genelinde kayıtların sahibi olarak kullanılan kimlik.
    /// Firebase etkinse Firebase UID, değilse Apple'ın kararlı kullanıcı kimliğidir.
    let id: String
    let appleUserID: String
    var displayName: String?
    var email: String?
}

enum AuthError: LocalizedError {
    case cancelled
    case missingIdentityToken
    case underlying(String)

    var errorDescription: String? {
        switch self {
        case .cancelled: return nil
        case .missingIdentityToken: return L10n.text("Apple kimlik doğrulama belirteci alınamadı.")
        case .underlying(let message): return message
        }
    }
}

@MainActor
protocol AuthServiceProtocol: AnyObject {
    var currentUser: AuthenticatedUser? { get }
    func restoreSession() async
    func signIn(with authorization: ASAuthorization) async throws
    func signOut()
    /// Sign in with Apple isteğine eklenecek nonce'ı hazırlar ve hash'ini döner.
    func prepareNonce() -> String
}

/// Sign in with Apple tabanlı kimlik doğrulama.
///
/// Apple'ın kararlı `user` kimliği doğrudan kullanılır; uygulama
/// yerel olarak (uygun olan yerlerde CloudKit ile) çalışmaya devam eder.
@MainActor
@Observable
final class AppleAuthService: AuthServiceProtocol {

    private(set) var currentUser: AuthenticatedUser?

    @ObservationIgnored private let keychain: KeychainStore
    @ObservationIgnored private var currentNonce: String?
    /// Kullanıcı kimliği değiştiğinde (örn. Firebase sonradan eklendiğinde)
    /// yerel kayıtların sahibini güncellemek için çağrılır.
    @ObservationIgnored var onUserIDMigration: (@MainActor (String, String) -> Void)?

    init(keychain: KeychainStore = KeychainStore()) {
        self.keychain = keychain
    }

    func restoreSession() async {
        guard let userID = keychain.get(KeychainStore.Key.userID),
              let appleUserID = keychain.get(KeychainStore.Key.appleUserID) else {
            currentUser = nil
            return
        }

        // Apple kimliğinin hâlâ geçerli olduğunu doğrula.
        let provider = ASAuthorizationAppleIDProvider()
        let state = try? await provider.credentialState(forUserID: appleUserID)

        switch state {
        case .revoked, .notFound:
            // Kullanıcı Apple ID ayarlarından izni geri çekmiş.
            signOut()
        default:
            // `.authorized`, `.transferred` ve sorgunun başarısız olduğu (çevrimdışı)
            // durumlarda saklanan oturum korunur — uygulama internetsiz de açılmalı.
            currentUser = AuthenticatedUser(
                id: userID,
                appleUserID: appleUserID,
                displayName: keychain.get(KeychainStore.Key.displayName),
                email: keychain.get(KeychainStore.Key.email)
            )
        }
    }

    func prepareNonce() -> String {
        let nonce = Self.randomNonceString()
        currentNonce = nonce
        return Self.sha256(nonce)
    }

    func signIn(with authorization: ASAuthorization) async throws {
        guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential else {
            throw AuthError.underlying(L10n.text("Beklenmeyen kimlik bilgisi türü."))
        }

        let appleUserID = credential.user
        let resolvedID = appleUserID



        // İsim yalnızca ilk girişte gelir; sonraki girişlerde saklanan değeri koruyoruz.
        let name = Self.formattedName(credential.fullName) ?? keychain.get(KeychainStore.Key.displayName)
        let email = credential.email ?? keychain.get(KeychainStore.Key.email)

        // Kimlik değiştiyse (ör. Firebase sonradan eklendi) yerel kayıtları taşı.
        if let previousID = keychain.get(KeychainStore.Key.userID), previousID != resolvedID {
            onUserIDMigration?(previousID, resolvedID)
        }

        keychain.set(resolvedID, for: KeychainStore.Key.userID)
        keychain.set(appleUserID, for: KeychainStore.Key.appleUserID)
        keychain.set(name, for: KeychainStore.Key.displayName)
        keychain.set(email, for: KeychainStore.Key.email)

        currentUser = AuthenticatedUser(
            id: resolvedID,
            appleUserID: appleUserID,
            displayName: name,
            email: email
        )
        currentNonce = nil
    }

    func signOut() {
        keychain.remove(KeychainStore.Key.userID)
        keychain.remove(KeychainStore.Key.appleUserID)
        keychain.remove(KeychainStore.Key.displayName)
        keychain.remove(KeychainStore.Key.email)

        currentUser = nil
    }

    #if DEBUG
    /// Yalnızca geliştirme içindir: Apple Developer hesabı / Sign in with Apple
    /// yeteneği henüz kurulmadan simülatörde uygulamayı denemek için.
    /// Release derlemesinde bu kod hiç yer almaz.
    func signInForDevelopment() {
        let devID = keychain.get(KeychainStore.Key.userID) ?? "local-dev-user"
        keychain.set(devID, for: KeychainStore.Key.userID)
        keychain.set(devID, for: KeychainStore.Key.appleUserID)
        keychain.set(L10n.text("Geliştirme Kullanıcısı"), for: KeychainStore.Key.displayName)
        currentUser = AuthenticatedUser(
            id: devID,
            appleUserID: devID,
            displayName: L10n.text("Geliştirme Kullanıcısı"),
            email: nil
        )
    }
    #endif

    // MARK: - Yardımcılar

    private static func formattedName(_ components: PersonNameComponents?) -> String? {
        guard let components else { return nil }
        let formatter = PersonNameComponentsFormatter()
        formatter.style = .default
        let name = formatter.string(from: components).trimmingCharacters(in: .whitespaces)
        return name.isEmpty ? nil : name
    }

    /// Firebase'in Apple girişinde talep ettiği tekrar kullanılamaz rastgele değer.
    private static func randomNonceString(length: Int = 32) -> String {
        let charset = Array("0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._")
        var result = ""
        var remaining = length

        while remaining > 0 {
            var random: UInt8 = 0
            let status = SecRandomCopyBytes(kSecRandomDefault, 1, &random)
            guard status == errSecSuccess else { continue }
            // Reddetme örneklemesi: yalnızca alfabe uzunluğundan küçük değerleri kullan,
            // böylece dağılım düzgün kalır.
            let index = Int(random)
            if index < charset.count {
                result.append(charset[index])
                remaining -= 1
            }
        }
        return result
    }

    private static func sha256(_ input: String) -> String {
        let data = Data(input.utf8)
        return SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }
}
