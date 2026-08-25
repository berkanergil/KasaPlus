import UIKit
import UserNotifications

/// Yerel bildirimlerin teslimini ve aksiyon butonlarını karşılayan delege.
/// SwiftUI `@UIApplicationDelegateAdaptor` ile bağlanır.
final class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        let center = UNUserNotificationCenter.current()
        center.delegate = self
        center.setNotificationCategories([PlannedPaymentNotifications.category])
        return true
    }

    /// Uygulama açıkken de bildirimi göster — kullanıcı "Ödedim / Ertele"
    /// butonlarını kaçırmasın.
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .list, .sound])
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        Task { @MainActor in
            NotificationRouter.shared.handle(response: response)
            completionHandler()
        }
    }
}
