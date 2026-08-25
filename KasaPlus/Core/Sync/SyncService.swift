import Foundation
import Observation

enum SyncState: Equatable, Sendable {
    case idle
    case syncing
    case succeeded(Date)
    case failed(String)
    case disabled

    var isSyncing: Bool { self == .syncing }
}

/// Yerel SwiftData deposu ile uzak depo arasındaki iki yönlü senkronizasyonu yönetir.
///
/// Strateji (PRD 5.4):
///  1. `lastSyncDate`'ten sonra değişen uzak kayıtları çek ve yerele uygula
///     (çakışmada `updatedAt` büyük olan kazanır — last-write-wins).
///  2. Yerelde bekleyen (henüz gönderilmemiş) değişiklikleri uzağa gönder.
///  3. Başarılıysa `lastSyncDate`'i güncelle ve gönderilmiş mezar taşlarını temizle.
@MainActor
@Observable
final class SyncService {

    private(set) var state: SyncState = .idle
    private(set) var lastSyncDate: Date?

    @ObservationIgnored private let transactionRepository: TransactionRepositoryProtocol
    @ObservationIgnored private let categoryRepository: CategoryRepositoryProtocol
    @ObservationIgnored private let bankRepository: BankRepositoryProtocol
    @ObservationIgnored private let plannedPaymentRepository: PlannedPaymentRepositoryProtocol
    @ObservationIgnored private let remote: RemoteDataSource
    @ObservationIgnored private let userID: String
    @ObservationIgnored private let defaults: UserDefaults
    @ObservationIgnored private var isRunning = false

    private var lastSyncKey: String { "sync.lastDate.\(userID)" }

    var isCloudConfigured: Bool { remote.isConfigured }
    var cloudStatusDescription: String { remote.statusDescription }

    init(
        transactionRepository: TransactionRepositoryProtocol,
        categoryRepository: CategoryRepositoryProtocol,
        bankRepository: BankRepositoryProtocol,
        plannedPaymentRepository: PlannedPaymentRepositoryProtocol,
        remote: RemoteDataSource,
        userID: String,
        defaults: UserDefaults = .standard
    ) {
        self.transactionRepository = transactionRepository
        self.categoryRepository = categoryRepository
        self.bankRepository = bankRepository
        self.plannedPaymentRepository = plannedPaymentRepository
        self.remote = remote
        self.userID = userID
        self.defaults = defaults

        let stored = defaults.double(forKey: "sync.lastDate.\(userID)")
        self.lastSyncDate = stored > 0 ? Date(timeIntervalSince1970: stored) : nil
        self.state = remote.isConfigured ? .idle : .disabled
    }

    /// Uygulama açılışında / öne gelişte ve arka plan görevinde çağrılır.
    /// Bulut yapılandırılmamışsa sessizce çıkar — kullanıcıya hata gösterilmez.
    @discardableResult
    func syncIfPossible() async -> Bool {
        guard remote.isConfigured else {
            state = .disabled
            return false
        }
        return await performSync()
    }

    /// Ayarlar ekranındaki "Şimdi Yedekle" butonu.
    @discardableResult
    func syncNow() async -> Bool {
        guard remote.isConfigured else {
            state = .failed(SyncError.notConfigured.localizedDescription)
            return false
        }
        return await performSync()
    }

    private func performSync() async -> Bool {
        guard !isRunning else { return false }
        isRunning = true
        state = .syncing
        defer { isRunning = false }

        do {
            // 1) Uzaktan çek — sıralama önemli: önce referans veriler (banka, kategori)
            let snapshot = try await remote.fetchChanges(since: lastSyncDate, userID: userID)
            for dto in snapshot.banks { try bankRepository.applyRemote(dto) }
            for dto in snapshot.categories { try categoryRepository.applyRemote(dto) }
            for dto in snapshot.transactions { try transactionRepository.applyRemote(dto) }
            for dto in snapshot.plannedPayments { try plannedPaymentRepository.applyRemote(dto) }

            // 2) Yereldeki bekleyenleri gönder
            let transactionDTOs = try transactionRepository.pendingChanges().map(TransactionDTO.init)
            let categoryDTOs = try categoryRepository.pendingChanges().map(CategoryDTO.init)
            let bankDTOs = try bankRepository.pendingChanges().map(BankDTO.init)
            let plannedDTOs = try plannedPaymentRepository.pendingChanges().map(PlannedPaymentDTO.init)

            let hasOutgoing = !transactionDTOs.isEmpty || !categoryDTOs.isEmpty
                || !bankDTOs.isEmpty || !plannedDTOs.isEmpty

            if hasOutgoing {
                try await remote.push(
                    transactions: transactionDTOs,
                    categories: categoryDTOs,
                    banks: bankDTOs,
                    plannedPayments: plannedDTOs,
                    userID: userID
                )
                let now = Date()
                try transactionRepository.markSynced(ids: transactionDTOs.map(\.id), at: now)
                try categoryRepository.markSynced(ids: categoryDTOs.map(\.id), at: now)
                try bankRepository.markSynced(ids: bankDTOs.map(\.id), at: now)
                try plannedPaymentRepository.markSynced(ids: plannedDTOs.map(\.id), at: now)
            }

            // 3) Tamamlandı
            let completedAt = Date()
            lastSyncDate = completedAt
            defaults.set(completedAt.timeIntervalSince1970, forKey: lastSyncKey)
            state = .succeeded(completedAt)

            // Buluta gönderilmiş, 30 günden eski mezar taşlarını temizle.
            try? transactionRepository.purgeSyncedTombstones(
                olderThan: completedAt.addingTimeInterval(-30 * 24 * 60 * 60)
            )
            return true
        } catch {
            state = .failed(error.localizedDescription)
            return false
        }
    }

    /// Ayarlar ekranında gösterilecek metin.
    var lastSyncDescription: String {
        guard remote.isConfigured else { return "Devre dışı" }
        guard let lastSyncDate else { return "Henüz yedeklenmedi" }
        return Formatters.dateTime.string(from: lastSyncDate)
    }
}
