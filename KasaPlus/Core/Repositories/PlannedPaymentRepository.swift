import Foundation
import SwiftData

/// Planlanan ödeme ekleme / düzenleme taslağı.
struct PlannedPaymentDraft: Equatable, Sendable {
    var id: UUID?
    var title: String
    var amount: Double
    var currency: Currency
    var dueDate: Date
    var categoryID: UUID?
    var paymentMethod: PaymentMethod
    var bankID: UUID?
    var note: String
    var reminderEnabled: Bool
    var isRecurring: Bool
    var recurrenceFrequency: RecurrenceFrequency
    var recurrenceEndDate: Date

    static func empty(currency: Currency = .TRY, calendar: Calendar = .turkish) -> PlannedPaymentDraft {
        // Varsayılan vade: bir hafta sonrası, sabah 09:00
        let base = calendar.date(byAdding: .day, value: 7, to: .now) ?? .now
        let due = calendar.date(
            bySettingHour: 9, minute: 0, second: 0, of: base
        ) ?? base

        return PlannedPaymentDraft(
            id: nil,
            title: "",
            amount: 0,
            currency: currency,
            dueDate: due,
            categoryID: nil,
            paymentMethod: .bankTransfer,
            bankID: nil,
            note: "",
            reminderEnabled: true,
            isRecurring: false,
            recurrenceFrequency: .monthly,
            recurrenceEndDate: calendar.date(byAdding: .year, value: 1, to: due) ?? due
        )
    }

    init(
        id: UUID? = nil,
        title: String,
        amount: Double,
        currency: Currency,
        dueDate: Date,
        categoryID: UUID?,
        paymentMethod: PaymentMethod,
        bankID: UUID?,
        note: String,
        reminderEnabled: Bool,
        isRecurring: Bool = false,
        recurrenceFrequency: RecurrenceFrequency = .monthly,
        recurrenceEndDate: Date? = nil
    ) {
        self.id = id
        self.title = title
        self.amount = amount
        self.currency = currency
        self.dueDate = dueDate
        self.categoryID = categoryID
        self.paymentMethod = paymentMethod
        self.bankID = bankID
        self.note = note
        self.reminderEnabled = reminderEnabled
        self.isRecurring = isRecurring
        self.recurrenceFrequency = recurrenceFrequency
        self.recurrenceEndDate = recurrenceEndDate
            ?? Calendar.turkish.date(byAdding: .year, value: 1, to: dueDate)
            ?? dueDate
    }

    init(payment: PlannedPayment) {
        self.id = payment.id
        self.title = payment.title
        self.amount = payment.amount
        self.currency = payment.currency
        self.dueDate = payment.dueDate
        self.categoryID = payment.categoryID
        self.paymentMethod = payment.paymentMethod
        self.bankID = payment.bankID
        self.note = payment.note ?? ""
        self.reminderEnabled = payment.reminderEnabled
        self.isRecurring = payment.isRecurring
        self.recurrenceFrequency = payment.recurrenceFrequency ?? .monthly
        self.recurrenceEndDate = payment.recurrenceEndDate
            ?? Calendar.turkish.date(byAdding: .year, value: 1, to: payment.dueDate)
            ?? payment.dueDate
    }

    var isValid: Bool {
        amount > 0
        && categoryID != nil
        && !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        && (!isRecurring || dueDate <= recurrenceEndDate.endOfDay())
    }

    var recurrenceOccurrenceCount: Int {
        guard isRecurring else { return 0 }
        return recurrenceFrequency.occurrenceDates(from: dueDate, through: recurrenceEndDate).count
    }
}

@MainActor
protocol PlannedPaymentRepositoryProtocol: AnyObject {
    func fetchAll() throws -> [PlannedPayment]
    func fetchPending() throws -> [PlannedPayment]
    func payment(id: UUID) throws -> PlannedPayment?
    @discardableResult func save(_ draft: PlannedPaymentDraft) throws -> PlannedPayment
    func delete(id: UUID) throws
    func postpone(id: UUID, to newDate: Date) throws
    /// Ödendi olarak işaretler ve karşılık gelen gider işlemini oluşturur.
    @discardableResult func markPaid(id: UUID, on date: Date) throws -> FinanceTransaction?
    func markPending(id: UUID) throws

    // Senkronizasyon
    func pendingChanges() throws -> [PlannedPayment]
    func markSynced(ids: [UUID], at date: Date) throws
    func applyRemote(_ dto: PlannedPaymentDTO) throws
}

@MainActor
final class SwiftDataPlannedPaymentRepository: PlannedPaymentRepositoryProtocol {

    private let context: ModelContext
    private let userID: String

    init(context: ModelContext, userID: String) {
        self.context = context
        self.userID = userID
    }

    func fetchAll() throws -> [PlannedPayment] {
        let currentUserID = userID
        let descriptor = FetchDescriptor<PlannedPayment>(
            predicate: #Predicate { $0.userID == currentUserID && $0.isRemoved == false },
            sortBy: [SortDescriptor(\.dueDate, order: .forward)]
        )
        return try context.fetch(descriptor)
    }

    func fetchPending() throws -> [PlannedPayment] {
        try fetchAll().filter { $0.status == .pending }
    }

    func payment(id: UUID) throws -> PlannedPayment? {
        var descriptor = FetchDescriptor<PlannedPayment>(predicate: #Predicate { $0.id == id })
        descriptor.fetchLimit = 1
        return try context.fetch(descriptor).first
    }

    @discardableResult
    func save(_ draft: PlannedPaymentDraft) throws -> PlannedPayment {
        guard draft.isValid, let categoryID = draft.categoryID else {
            throw RepositoryError.invalidDraft
        }

        let title = draft.title.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedNote = draft.note.trimmingCharacters(in: .whitespacesAndNewlines)
        let bankID = draft.paymentMethod.requiresBank ? draft.bankID : nil

        if let id = draft.id, let existing = try payment(id: id) {
            existing.title = title
            existing.amount = draft.amount
            existing.currency = draft.currency
            existing.dueDate = draft.dueDate
            existing.categoryID = categoryID
            existing.paymentMethod = draft.paymentMethod
            existing.bankID = bankID
            existing.note = trimmedNote.isEmpty ? nil : trimmedNote
            existing.reminderEnabled = draft.reminderEnabled
            updateRecurrence(on: existing, from: draft)

            if draft.isRecurring, existing.recurrenceGroupID == nil {
                let groupID = UUID()
                existing.recurrenceGroupID = groupID
                createFutureOccurrences(
                    from: draft,
                    after: existing.dueDate,
                    recurrenceGroupID: groupID,
                    categoryID: categoryID,
                    bankID: bankID,
                    trimmedNote: trimmedNote
                )
            }
            existing.updatedAt = .now
            try context.save()
            return existing
        }

        let recurrenceGroupID = draft.isRecurring ? UUID() : nil
        let dates = draft.isRecurring
            ? draft.recurrenceFrequency.occurrenceDates(from: draft.dueDate, through: draft.recurrenceEndDate)
            : [draft.dueDate]
        guard let firstDate = dates.first else { throw RepositoryError.invalidDraft }

        let created = makePayment(
            from: draft,
            dueDate: firstDate,
            categoryID: categoryID,
            bankID: bankID,
            trimmedNote: trimmedNote,
            recurrenceGroupID: recurrenceGroupID
        )
        context.insert(created)

        for dueDate in dates.dropFirst() {
            context.insert(makePayment(
                from: draft,
                dueDate: dueDate,
                categoryID: categoryID,
                bankID: bankID,
                trimmedNote: trimmedNote,
                recurrenceGroupID: recurrenceGroupID
            ))
        }
        try context.save()
        return created
    }

    private func updateRecurrence(on payment: PlannedPayment, from draft: PlannedPaymentDraft) {
        guard draft.isRecurring else {
            payment.recurrenceGroupID = nil
            payment.recurrenceFrequency = nil
            payment.recurrenceEndDate = nil
            return
        }
        payment.recurrenceFrequency = draft.recurrenceFrequency
        payment.recurrenceEndDate = draft.recurrenceEndDate
    }

    private func makePayment(
        from draft: PlannedPaymentDraft,
        dueDate: Date,
        categoryID: UUID,
        bankID: UUID?,
        trimmedNote: String,
        recurrenceGroupID: UUID?
    ) -> PlannedPayment {
        PlannedPayment(
            title: draft.title.trimmingCharacters(in: .whitespacesAndNewlines),
            amount: draft.amount,
            currency: draft.currency,
            dueDate: dueDate,
            categoryID: categoryID,
            paymentMethod: draft.paymentMethod,
            bankID: bankID,
            note: trimmedNote.isEmpty ? nil : trimmedNote,
            reminderEnabled: draft.reminderEnabled,
            recurrenceGroupID: recurrenceGroupID,
            recurrenceFrequency: draft.isRecurring ? draft.recurrenceFrequency : nil,
            recurrenceEndDate: draft.isRecurring ? draft.recurrenceEndDate : nil,
            userID: userID
        )
    }

    private func createFutureOccurrences(
        from draft: PlannedPaymentDraft,
        after dueDate: Date,
        recurrenceGroupID: UUID,
        categoryID: UUID,
        bankID: UUID?,
        trimmedNote: String
    ) {
        let dates = draft.recurrenceFrequency.occurrenceDates(from: draft.dueDate, through: draft.recurrenceEndDate)
        for occurrenceDate in dates where occurrenceDate > dueDate {
            context.insert(makePayment(
                from: draft,
                dueDate: occurrenceDate,
                categoryID: categoryID,
                bankID: bankID,
                trimmedNote: trimmedNote,
                recurrenceGroupID: recurrenceGroupID
            ))
        }
    }

    func delete(id: UUID) throws {
        guard let target = try payment(id: id) else { throw RepositoryError.notFound }
        target.isRemoved = true
        target.updatedAt = .now
        try context.save()
    }

    func postpone(id: UUID, to newDate: Date) throws {
        guard let target = try payment(id: id) else { throw RepositoryError.notFound }
        target.dueDate = newDate
        target.status = .pending
        target.postponeCount += 1
        target.updatedAt = .now
        try context.save()
    }

    /// Planlanan ödemeyi gerçek bir gider işlemine dönüştürür.
    /// Zaten ödenmişse yeni işlem oluşturmaz (bildirim iki kez işlense bile güvenli).
    @discardableResult
    func markPaid(id: UUID, on date: Date) throws -> FinanceTransaction? {
        guard let target = try payment(id: id) else { throw RepositoryError.notFound }
        guard target.status != .paid else { return nil }

        let transaction = FinanceTransaction(
            amount: target.amount,
            date: date,
            type: .expense,
            currency: target.currency,
            paymentMethod: target.paymentMethod,
            categoryID: target.categoryID,
            bankID: target.bankID,
            note: [target.title, target.note].compactMap { $0 }.joined(separator: " — "),
            userID: target.userID
        )
        context.insert(transaction)

        target.status = .paid
        target.paidAt = date
        target.paidTransactionID = transaction.id
        target.updatedAt = .now

        try context.save()
        return transaction
    }

    /// "Ödendi" işaretini geri alır (oluşturulan gider işlemi de silinir).
    func markPending(id: UUID) throws {
        guard let target = try payment(id: id) else { throw RepositoryError.notFound }

        if let transactionID = target.paidTransactionID {
            var descriptor = FetchDescriptor<FinanceTransaction>(
                predicate: #Predicate { $0.id == transactionID }
            )
            descriptor.fetchLimit = 1
            if let transaction = try context.fetch(descriptor).first {
                transaction.isRemoved = true
                transaction.updatedAt = .now
            }
        }

        target.status = .pending
        target.paidAt = nil
        target.paidTransactionID = nil
        target.updatedAt = .now
        try context.save()
    }

    // MARK: - Senkronizasyon

    func pendingChanges() throws -> [PlannedPayment] {
        let currentUserID = userID
        let descriptor = FetchDescriptor<PlannedPayment>(
            predicate: #Predicate { $0.userID == currentUserID }
        )
        return try context.fetch(descriptor).filter { $0.hasPendingChanges }
    }

    func markSynced(ids: [UUID], at date: Date) throws {
        for id in ids {
            if let target = try payment(id: id) { target.syncedAt = date }
        }
        try context.save()
    }

    func applyRemote(_ dto: PlannedPaymentDTO) throws {
        if let existing = try payment(id: dto.id) {
            guard dto.updatedAt > existing.updatedAt else { return }
            existing.title = dto.title
            existing.amount = dto.amount
            existing.currencyRaw = dto.currency
            existing.dueDate = dto.dueDate
            existing.categoryID = dto.categoryID
            existing.paymentMethodRaw = dto.paymentMethod
            existing.bankID = dto.bankID
            existing.note = dto.note
            existing.statusRaw = dto.status
            existing.paidTransactionID = dto.paidTransactionID
            existing.paidAt = dto.paidAt
            existing.reminderEnabled = dto.reminderEnabled
            existing.postponeCount = dto.postponeCount
            existing.recurrenceGroupID = dto.recurrenceGroupID
            existing.recurrenceFrequencyRaw = dto.recurrenceFrequency
            existing.recurrenceEndDate = dto.recurrenceEndDate
            existing.updatedAt = dto.updatedAt
            existing.isRemoved = dto.isDeleted
            existing.syncedAt = .now
        } else {
            let created = PlannedPayment(
                id: dto.id,
                title: dto.title,
                amount: dto.amount,
                currency: Currency.from(rawValue: dto.currency),
                dueDate: dto.dueDate,
                categoryID: dto.categoryID,
                paymentMethod: PaymentMethod.from(rawValue: dto.paymentMethod),
                bankID: dto.bankID,
                note: dto.note,
                status: PlannedPaymentStatus(rawValue: dto.status) ?? .pending,
                paidTransactionID: dto.paidTransactionID,
                paidAt: dto.paidAt,
                reminderEnabled: dto.reminderEnabled,
                postponeCount: dto.postponeCount,
                recurrenceGroupID: dto.recurrenceGroupID,
                recurrenceFrequency: dto.recurrenceFrequency.flatMap(RecurrenceFrequency.init(rawValue:)),
                recurrenceEndDate: dto.recurrenceEndDate,
                userID: dto.userID,
                createdAt: dto.createdAt,
                updatedAt: dto.updatedAt,
                isRemoved: dto.isDeleted,
                syncedAt: .now
            )
            context.insert(created)
        }
        try context.save()
    }
}
