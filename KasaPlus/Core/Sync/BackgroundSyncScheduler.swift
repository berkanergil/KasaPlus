import Foundation
import BackgroundTasks

/// Arka planda periyodik yedekleme (PRD 5.4).
///
/// Info.plist tarafında `BGTaskSchedulerPermittedIdentifiers` içine
/// `com.kasaplus.sync` kimliği eklenmiştir (Xcode build settings üzerinden).
/// Ayrıca hedefte **Background Modes → Background processing** yeteneği açık olmalıdır.
///
/// iOS görevleri kesin zamanlarda çalıştırmaz; sistem pil/şebeke durumuna göre
/// uygun bir zamanda tetikler. Bu yüzden uygulama öne geldiğinde de senkronizasyon yapılır.
enum BackgroundSyncScheduler {

    static let taskIdentifier = "com.kasaplus.sync"

    /// En erken 4 saat sonra tekrar denensin.
    private static let earliestInterval: TimeInterval = 4 * 60 * 60

    /// `KasaPlusApp` içinde, uygulama başlar başlamaz (init) çağrılmalıdır.
    static func register(handler: @escaping @Sendable () async -> Void) {
        _ = BGTaskScheduler.shared.register(
            forTaskWithIdentifier: taskIdentifier,
            using: nil
        ) { task in
            guard let task = task as? BGProcessingTask else {
                task.setTaskCompleted(success: false)
                return
            }
            schedule() // bir sonrakini hemen kuyruğa al

            let work = Task {
                await handler()
                task.setTaskCompleted(success: true)
            }

            task.expirationHandler = {
                work.cancel()
                task.setTaskCompleted(success: false)
            }
        }
    }

    static func schedule() {
        let request = BGProcessingTaskRequest(identifier: taskIdentifier)
        request.requiresNetworkConnectivity = true
        request.requiresExternalPower = false
        request.earliestBeginDate = Date(timeIntervalSinceNow: earliestInterval)

        do {
            try BGTaskScheduler.shared.submit(request)
        } catch {
            // Simülatörde ve arka plan yenileme kapalıyken hata beklenen bir durumdur.
            #if DEBUG
            print("[BackgroundSync] Görev kuyruğa alınamadı: \(error.localizedDescription)")
            #endif
        }
    }
}
