import SwiftUI
import AuthenticationServices

/// Karşılama ve Apple ile giriş ekranı (PRD 4).
struct SignInView: View {

    @Environment(AppleAuthService.self) private var authService
    @Environment(\.colorScheme) private var colorScheme

    @State private var errorMessage: String?
    @State private var isWorking = false

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            VStack(spacing: 20) {
                AppLogoMark(size: 96)

                VStack(spacing: 8) {
                    Text("Kasa+")
                        .font(.largeTitle.bold())
                    Text("Eczanenizin günlük gelir ve giderlerini\nsaniyeler içinde kaydedin.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
            }

            Spacer()

            VStack(alignment: .leading, spacing: 18) {
                FeatureRow(
                    icon: "bolt.fill",
                    title: "Hızlı kayıt",
                    detail: "Gelir veya gideri iki dokunuşla ekleyin."
                )
                FeatureRow(
                    icon: "chart.line.uptrend.xyaxis",
                    title: "Net raporlar",
                    detail: "Haftalık, aylık ve yıllık kırılımlar."
                )
                FeatureRow(
                    icon: "wifi.slash",
                    title: "İnternetsiz çalışır",
                    detail: "Veriler cihazınızda; bağlantı gelince yedeklenir."
                )
            }
            .frame(maxWidth: 420)
            .padding(.horizontal, 32)

            Spacer()

            VStack(spacing: 12) {
                SignInWithAppleButton(.signIn) { request in
                    request.requestedScopes = [.fullName, .email]
                    request.nonce = authService.prepareNonce()
                } onCompletion: { result in
                    handle(result)
                }
                .signInWithAppleButtonStyle(colorScheme == .dark ? .white : .black)
                .frame(height: 50)
                .disabled(isWorking)

                #if DEBUG
                Button("Geliştirme modunda devam et") {
                    authService.signInForDevelopment()
                }
                .font(.footnote)
                .foregroundStyle(.secondary)
                #endif

                if let errorMessage {
                    Text(errorMessage)
                        .font(.footnote)
                        .foregroundStyle(AppTheme.expense)
                        .multilineTextAlignment(.center)
                }

                Text("Verileriniz cihazınızda saklanır ve yalnızca sizin hesabınıza yedeklenir.")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                    .multilineTextAlignment(.center)
                    .padding(.top, 4)
            }
            .frame(maxWidth: 420)
            .padding(.horizontal, 32)
            .padding(.bottom, 32)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemGroupedBackground))
    }

    private func handle(_ result: Result<ASAuthorization, Error>) {
        switch result {
        case .success(let authorization):
            isWorking = true
            Task {
                do {
                    try await authService.signIn(with: authorization)
                    errorMessage = nil
                } catch {
                    errorMessage = error.localizedDescription
                }
                isWorking = false
            }
        case .failure(let error):
            // Kullanıcı iptal ettiyse hata göstermeye gerek yok.
            if (error as? ASAuthorizationError)?.code == .canceled {
                errorMessage = nil
            } else {
                errorMessage = "Giriş tamamlanamadı: \(error.localizedDescription)"
            }
        }
    }
}

private struct FeatureRow: View {
    let icon: String
    let title: String
    let detail: String

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(AppTheme.accent)
                .frame(width: 28, height: 28)
                .background(AppTheme.accent.opacity(0.12), in: RoundedRectangle(cornerRadius: 8, style: .continuous))

            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.subheadline.weight(.semibold))
                Text(detail).font(.footnote).foregroundStyle(.secondary)
            }
        }
    }
}

#Preview {
    SignInView()
        .environment(AppleAuthService())
}
