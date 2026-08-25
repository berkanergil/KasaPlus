import SwiftUI

/// Uygulama kilidi ekranı. Face ID / Touch ID başarısız olursa
/// cihaz parolası fallback olarak devreye girer (PRD 4).
struct LockedView: View {

    @Environment(BiometricLockService.self) private var lockService

    var body: some View {
        ZStack {
            Rectangle()
                .fill(.ultraThinMaterial)
                .ignoresSafeArea()

            VStack(spacing: 24) {
                AppLogoMark(size: 80)

                VStack(spacing: 6) {
                    Text("Kasa+ kilitli")
                        .font(.title2.bold())
                    Text("Devam etmek için kimliğinizi doğrulayın.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                if let message = lockService.lastErrorMessage {
                    Text(message)
                        .font(.footnote)
                        .foregroundStyle(AppTheme.expense)
                }

                Button {
                    Task { await lockService.unlock() }
                } label: {
                    Label(
                        lockService.isAuthenticating ? "Doğrulanıyor…" : "\(lockService.biometryDescription) ile aç",
                        systemImage: "lock.open.fill"
                    )
                    .font(.headline)
                    .frame(maxWidth: 280)
                    .padding(.vertical, 14)
                }
                .buttonStyle(.borderedProminent)
                .disabled(lockService.isAuthenticating)
            }
            .padding(32)
        }
        .task {
            // Ekran görünür görünmez doğrulamayı otomatik başlat.
            await lockService.unlock()
        }
    }
}

#Preview {
    LockedView()
        .environment(BiometricLockService())
}
