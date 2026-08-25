import Foundation
import SwiftData

/// Kullanıcı kimliği değiştiğinde (örneğin Firebase sonradan devreye alındığında,
/// yerel Apple kimliği yerine Firebase UID kullanılmaya başlandığında) mevcut
/// yerel kayıtların sahibini günceller. Böylece kullanıcı verisi kaybolmuş görünmez.
enum OwnershipMigrator {

    @MainActor
    static func reassign(from oldUserID: String, to newUserID: String, context: ModelContext) {
        guard oldUserID != newUserID, !oldUserID.isEmpty, !newUserID.isEmpty else { return }

        let transactionDescriptor = FetchDescriptor<FinanceTransaction>(
            predicate: #Predicate { $0.userID == oldUserID }
        )
        let categoryDescriptor = FetchDescriptor<Category>(
            predicate: #Predicate { $0.userID == oldUserID }
        )
        let bankDescriptor = FetchDescriptor<Bank>(
            predicate: #Predicate { $0.userID == oldUserID }
        )
        let plannedDescriptor = FetchDescriptor<PlannedPayment>(
            predicate: #Predicate { $0.userID == oldUserID }
        )

        let transactions = (try? context.fetch(transactionDescriptor)) ?? []
        let categories = (try? context.fetch(categoryDescriptor)) ?? []
        let banks = (try? context.fetch(bankDescriptor)) ?? []
        let plannedPayments = (try? context.fetch(plannedDescriptor)) ?? []

        guard !transactions.isEmpty || !categories.isEmpty
                || !banks.isEmpty || !plannedPayments.isEmpty else { return }

        let now = Date()
        for item in transactions {
            item.userID = newUserID
            item.updatedAt = now
            item.syncedAt = nil // yeni hesap altına yeniden yüklensin
        }
        for item in categories {
            item.userID = newUserID
            item.updatedAt = now
            item.syncedAt = nil
        }
        for item in banks {
            item.userID = newUserID
            item.updatedAt = now
            item.syncedAt = nil
        }
        for item in plannedPayments {
            item.userID = newUserID
            item.updatedAt = now
            item.syncedAt = nil
        }
        try? context.save()
    }
}
