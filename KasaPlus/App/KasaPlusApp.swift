import SwiftUI
import SwiftData



@main
struct KasaPlusApp: App {

    /// Yerel bildirimlerin teslimini ve aksiyon butonlarını karşılar.
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    private let modelContainer: ModelContainer

    @State private var authService: AppleAuthService
    @State private var settings = AppSettings()
    @State private var lockService = BiometricLockService()
    @State private var exchangeRates = ExchangeRateService()
    @State private var notificationService = NotificationService()
    @State private var notificationRouter = NotificationRouter.shared

    @Environment(\.scenePhase) private var scenePhase

    init() {


        // 2) Yerel depo
        let container = PersistenceController.makeContainer()
        self.modelContainer = container

        // 3) Bildirim aksiyonlarının veriye erişebilmesi için konteyneri paylaş.
        //    ("Ödedim" butonu uygulama kapalıyken de çalışmalı.)
        NotificationContainer.shared = container

        // 4) Kimlik doğrulama servisi + kimlik değişiminde veri taşıma
        let auth = AppleAuthService()
        auth.onUserIDMigration = { oldID, newID in
            OwnershipMigrator.reassign(from: oldID, to: newID, context: container.mainContext)
        }
        _authService = State(initialValue: auth)

        // 5) Arka plan senkronizasyon görevini kaydet (uygulama başlar başlamaz yapılmalı)
        BackgroundSyncScheduler.register { [container] in
            await BackgroundSyncRunner.run(container: container)
        }
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(authService)
                .environment(settings)
                .environment(lockService)
                .environment(exchangeRates)
                .environment(notificationService)
                .environment(notificationRouter)
                .environment(\.locale, settings.language.locale)
                .preferredColorScheme(settings.appearance.colorScheme)
                .tint(AppTheme.accent)
        }
        .modelContainer(modelContainer)
        .onChange(of: scenePhase) { _, newPhase in
            switch newPhase {
            case .active:
                lockService.applicationDidBecomeActive()
                Task { await notificationService.refreshAuthorizationStatus() }
            case .inactive:
                lockService.applicationWillResignActive()
            case .background:
                BackgroundSyncScheduler.schedule()
            @unknown default:
                break
            }
        }
    }
}
