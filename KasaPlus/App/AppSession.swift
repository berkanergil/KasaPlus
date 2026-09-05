import Foundation
import SwiftData
import Observation

/// Oturum açmış kullanıcıya bağlı bağımlılık kabı (composition root).
///
/// Tüm ViewModel'ler veri erişimini bu nesnedeki repository protokolleri üzerinden yapar.
/// `dataVersion` her yazma sonrası artar; ekranlar bunu izleyerek kendilerini tazeler —
/// böylece SwiftData'ya doğrudan bağlı olmadan reaktif kalırlar.
@MainActor
@Observable
final class AppSession {

    let user: AuthenticatedUser

    @ObservationIgnored let transactionRepository: TransactionRepositoryProtocol
    @ObservationIgnored let categoryRepository: CategoryRepositoryProtocol
    @ObservationIgnored let bankRepository: BankRepositoryProtocol
    @ObservationIgnored let plannedPaymentRepository: PlannedPaymentRepositoryProtocol
    @ObservationIgnored let syncService: SyncService
    @ObservationIgnored let notificationService: NotificationService

    /// Kategoriler ve bankalar az sayıda olduğu için bellekte tutulur.
    private(set) var categories: [Category] = []
    private(set) var banks: [Bank] = []
    /// Herhangi bir yazma işleminden sonra artar.
    private(set) var dataVersion: Int = 0
    private(set) var lastErrorMessage: String?

    init(
        user: AuthenticatedUser,
        modelContext: ModelContext,
        notificationService: NotificationService,
        remote: RemoteDataSource = RemoteDataSourceFactory.make()
    ) {
        self.user = user
        self.notificationService = notificationService

        let transactionRepository = SwiftDataTransactionRepository(context: modelContext, userID: user.id)
        let categoryRepository = SwiftDataCategoryRepository(context: modelContext, userID: user.id)
        let bankRepository = SwiftDataBankRepository(context: modelContext, userID: user.id)
        let plannedPaymentRepository = SwiftDataPlannedPaymentRepository(context: modelContext, userID: user.id)

        self.transactionRepository = transactionRepository
        self.categoryRepository = categoryRepository
        self.bankRepository = bankRepository
        self.plannedPaymentRepository = plannedPaymentRepository

        self.syncService = SyncService(
            transactionRepository: transactionRepository,
            categoryRepository: categoryRepository,
            bankRepository: bankRepository,
            plannedPaymentRepository: plannedPaymentRepository,
            remote: remote,
            userID: user.id
        )

        try? categoryRepository.seedDefaultsIfNeeded()
        try? bankRepository.seedDefaultsIfNeeded()
        reloadLookups()

        // Bildirimden gelen "Ödedim" aksiyonu veriyi değiştirdiğinde ekranlar tazelensin.
        NotificationRouter.shared.onDataChanged = { [weak self] in
            self?.dataVersion &+= 1
            self?.scheduleReminders()
        }
    }

    // MARK: - Sözlükler (kategori & banka)

    func reloadLookups() {
        categories = (try? categoryRepository.fetchAll()) ?? []
        banks = (try? bankRepository.fetchAll()) ?? []
    }

    func categories(for type: TransactionType) -> [Category] {
        categories.filter { $0.type == type }
    }

    func category(id: UUID?) -> Category? {
        guard let id else { return nil }
        return categories.first { $0.id == id }
    }

    func categoryName(id: UUID?) -> String {
        category(id: id)?.name ?? L10n.text("Silinmiş kategori")
    }

    func bank(id: UUID?) -> Bank? {
        guard let id else { return nil }
        return banks.first { $0.id == id }
    }

    func bankName(id: UUID?) -> String? {
        guard let id else { return nil }
        return banks.first { $0.id == id }?.name ?? L10n.text("Silinmiş banka")
    }

    // MARK: - İşlemler

    @discardableResult
    func saveTransaction(_ draft: TransactionDraft) -> Bool {
        perform { try transactionRepository.save(draft) }
    }

    @discardableResult
    func deleteTransaction(id: UUID) -> Bool {
        perform { try transactionRepository.delete(id: id) }
    }

    func fetchTransactions(_ filter: TransactionFilter) -> [FinanceTransaction] {
        (try? transactionRepository.fetch(filter)) ?? []
    }

    // MARK: - Kategoriler

    @discardableResult
    func saveCategory(_ draft: CategoryDraft) -> Bool {
        let result = perform { try categoryRepository.save(draft) }
        reloadLookups()
        return result
    }

    @discardableResult
    func deleteCategory(id: UUID) -> Bool {
        let result = perform { try categoryRepository.delete(id: id) }
        reloadLookups()
        return result
    }

    @discardableResult
    func reorderCategories(ids: [UUID]) -> Bool {
        let result = perform { try categoryRepository.reorder(ids: ids) }
        reloadLookups()
        return result
    }

    func transactionCount(categoryID: UUID) -> Int {
        (try? categoryRepository.transactionCount(categoryID: categoryID)) ?? 0
    }

    // MARK: - Bankalar

    @discardableResult
    func saveBank(_ draft: BankDraft) -> Bool {
        let result = perform { try bankRepository.save(draft) }
        reloadLookups()
        return result
    }

    @discardableResult
    func deleteBank(id: UUID) -> Bool {
        let result = perform { try bankRepository.delete(id: id) }
        reloadLookups()
        return result
    }

    @discardableResult
    func reorderBanks(ids: [UUID]) -> Bool {
        let result = perform { try bankRepository.reorder(ids: ids) }
        reloadLookups()
        return result
    }

    func transactionCount(bankID: UUID) -> Int {
        (try? bankRepository.transactionCount(bankID: bankID)) ?? 0
    }

    // MARK: - Planlanan ödemeler

    func fetchPlannedPayments() -> [PlannedPayment] {
        (try? plannedPaymentRepository.fetchAll()) ?? []
    }

    func plannedPayment(id: UUID) -> PlannedPayment? {
        try? plannedPaymentRepository.payment(id: id)
    }

    /// Önümüzdeki `days` gün içinde vadesi gelen (veya gecikmiş) bekleyen ödemeler.
    func upcomingPlannedPayments(within days: Int = 7) -> [PlannedPayment] {
        let pending = (try? plannedPaymentRepository.fetchPending()) ?? []
        return pending.filter { $0.daysRemaining() <= days }
    }

    @discardableResult
    func savePlannedPayment(_ draft: PlannedPaymentDraft) -> Bool {
        let result = perform { try plannedPaymentRepository.save(draft) }
        scheduleReminders()
        return result
    }

    @discardableResult
    func deletePlannedPayment(id: UUID) -> Bool {
        let result = perform { try plannedPaymentRepository.delete(id: id) }
        notificationService.cancel(paymentID: id)
        scheduleReminders()
        return result
    }

    @discardableResult
    func postponePlannedPayment(id: UUID, to newDate: Date) -> Bool {
        let result = perform { try plannedPaymentRepository.postpone(id: id, to: newDate) }
        scheduleReminders()
        return result
    }

    /// Planlanan ödemeyi gerçek gidere dönüştürür.
    @discardableResult
    func markPlannedPaymentPaid(id: UUID, on date: Date = .now) -> Bool {
        let result = perform { try plannedPaymentRepository.markPaid(id: id, on: date) }
        notificationService.cancel(paymentID: id)
        scheduleReminders()
        return result
    }

    @discardableResult
    func markPlannedPaymentPending(id: UUID) -> Bool {
        let result = perform { try plannedPaymentRepository.markPending(id: id) }
        scheduleReminders()
        return result
    }

    /// Tüm bekleyen ödemeler için bildirimleri baştan kurar.
    func scheduleReminders() {
        let payments = (try? plannedPaymentRepository.fetchPending()) ?? []
        let lookup: (UUID) -> String? = { [weak self] id in self?.category(id: id)?.name }
        Task {
            await notificationService.reschedule(payments: payments, categoryName: lookup)
        }
    }

    // MARK: - Ortak

    func clearError() { lastErrorMessage = nil }

    @discardableResult
    private func perform<T>(_ work: () throws -> T) -> Bool {
        do {
            _ = try work()
            dataVersion &+= 1
            lastErrorMessage = nil
            return true
        } catch {
            lastErrorMessage = error.localizedDescription
            return false
        }
    }
}
