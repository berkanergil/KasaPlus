import Foundation
import SwiftData

/// Arka plan görevinden (BGTaskScheduler) çağrılan bağımsız senkronizasyon akışı.
/// Arayüz katmanına hiç dokunmaz; kendi repository örneklerini kurar.
enum BackgroundSyncRunner {

    @MainActor
    static func run(container: ModelContainer) async {
        let keychain = KeychainStore()
        guard let userID = keychain.get(KeychainStore.Key.userID), !userID.isEmpty else { return }

        let context = container.mainContext
        let transactionRepository = SwiftDataTransactionRepository(context: context, userID: userID)
        let categoryRepository = SwiftDataCategoryRepository(context: context, userID: userID)
        let bankRepository = SwiftDataBankRepository(context: context, userID: userID)
        let plannedPaymentRepository = SwiftDataPlannedPaymentRepository(context: context, userID: userID)
        let service = SyncService(
            transactionRepository: transactionRepository,
            categoryRepository: categoryRepository,
            bankRepository: bankRepository,
            plannedPaymentRepository: plannedPaymentRepository,
            remote: RemoteDataSourceFactory.make(),
            userID: userID
        )
        await service.syncIfPossible()
    }
}
