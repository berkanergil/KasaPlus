import SwiftUI
import SwiftData

/// Uygulamanın giriş noktası: oturum durumuna ve uygulama kilidine göre
/// doğru ekranı gösterir.
struct RootView: View {

    @Environment(AppleAuthService.self) private var authService
    @Environment(BiometricLockService.self) private var lockService
    @Environment(ExchangeRateService.self) private var exchangeRates
    @Environment(NotificationService.self) private var notificationService
    @Environment(\.modelContext) private var modelContext
    @Environment(\.scenePhase) private var scenePhase

    @State private var session: AppSession?
    @State private var isRestoringSession = true

    var body: some View {
        ZStack {
            content
                .blur(radius: lockService.isLocked ? 24 : 0)
                .allowsHitTesting(!lockService.isLocked)

            if lockService.isLocked {
                LockedView()
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.2), value: lockService.isLocked)
        .task {
            await bootstrap()
        }
        .onChange(of: authService.currentUser) { _, newUser in
            rebuildSession(for: newUser)
        }
        .onChange(of: scenePhase) { _, newPhase in
            guard newPhase == .active else { return }
            Task {
                await exchangeRates.refreshIfNeeded()
                await session?.syncService.syncIfPossible()
            }
        }
    }

    @ViewBuilder
    private var content: some View {
        if isRestoringSession {
            LaunchPlaceholderView()
        } else if let session {
            MainTabView()
                .environment(session)
        } else {
            SignInView()
        }
    }

    private func bootstrap() async {
        lockService.applicationDidLaunch()
        await authService.restoreSession()
        rebuildSession(for: authService.currentUser)
        isRestoringSession = false

        await exchangeRates.refreshIfNeeded()
        await notificationService.refreshAuthorizationStatus()
        await session?.syncService.syncIfPossible()
        session?.scheduleReminders()
    }

    private func rebuildSession(for user: AuthenticatedUser?) {
        guard let user else {
            session = nil
            return
        }
        if session?.user.id != user.id {
            session = AppSession(
                user: user,
                modelContext: modelContext,
                notificationService: notificationService
            )
        }
    }
}

/// Oturum geri yüklenirken görünen kısa geçiş ekranı.
private struct LaunchPlaceholderView: View {
    var body: some View {
        VStack(spacing: 16) {
            AppLogoMark(size: 72)
            ProgressView()
                .controlSize(.small)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemGroupedBackground))
    }
}

/// Uygulama logosu — giriş ve kilit ekranlarında kullanılır.
struct AppLogoMark: View {
    var size: CGFloat = 64

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: size * 0.24, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [AppTheme.income, AppTheme.accent],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
            Image(systemName: "plus.forwardslash.minus")
                .font(.system(size: size * 0.42, weight: .bold))
                .foregroundStyle(.white)
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }
}
