import Foundation
import SwiftData

/// Tek bir gelir/gider kaydı.
///
/// Not: Enum alanları SwiftData'da doğrudan değil, `String` rawValue olarak saklanır.
/// Bu sayede ileride enum'a yeni case eklendiğinde şema göçü (migration) gerekmez.
@Model
final class FinanceTransaction {
    /// Kararlı kimlik — Firestore doküman kimliği olarak da kullanılır.
    @Attribute(.unique) var id: UUID

    var amount: Double
    var date: Date

    /// `TransactionType.rawValue`
    var typeRaw: String
    /// `Currency.rawValue`
    var currencyRaw: String
    /// `PaymentMethod.rawValue`
    var paymentMethodRaw: String

    /// İlişki yerine düz kimlik tutulur — senkronizasyonu ve çakışma çözümünü basitleştirir.
    var categoryID: UUID

    /// Nakit dışı ödeme yöntemlerinde işlemin bağlı olduğu banka.
    /// Nakit işlemlerde ve eski kayıtlarda `nil`'dir.
    var bankID: UUID?

    var note: String?

    // MARK: - Çoklu kullanıcı / senkronizasyon alanları

    /// Şu an tek kullanıcı olsa da baştan bulunur (bkz. PRD 7.3).
    var userID: String

    var createdAt: Date
    /// Çakışma çözümü "last-write-wins" bu alana göre yapılır.
    var updatedAt: Date
    /// Silinen kayıtlar için mezar taşı (tombstone) — uzak tarafa silmeyi bildirebilmek için.
    var isRemoved: Bool
    /// Buluta en son ne zaman gönderildiği. `nil` ise henüz senkronize edilmemiş.
    var syncedAt: Date?

    init(
        id: UUID = UUID(),
        amount: Double,
        date: Date = .now,
        type: TransactionType,
        currency: Currency = .TRY,
        paymentMethod: PaymentMethod = .cash,
        categoryID: UUID,
        bankID: UUID? = nil,
        note: String? = nil,
        userID: String,
        createdAt: Date = .now,
        updatedAt: Date = .now,
        isRemoved: Bool = false,
        syncedAt: Date? = nil
    ) {
        self.id = id
        self.amount = amount
        self.date = date
        self.typeRaw = type.rawValue
        self.currencyRaw = currency.rawValue
        self.paymentMethodRaw = paymentMethod.rawValue
        self.categoryID = categoryID
        self.bankID = bankID
        self.note = note
        self.userID = userID
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.isRemoved = isRemoved
        self.syncedAt = syncedAt
    }
}

// MARK: - Tip güvenli erişimciler

extension FinanceTransaction {
    var type: TransactionType {
        get { TransactionType(rawValue: typeRaw) ?? .expense }
        set { typeRaw = newValue.rawValue }
    }

    var currency: Currency {
        get { Currency.from(rawValue: currencyRaw) }
        set { currencyRaw = newValue.rawValue }
    }

    var paymentMethod: PaymentMethod {
        get { PaymentMethod.from(rawValue: paymentMethodRaw) }
        set { paymentMethodRaw = newValue.rawValue }
    }

    /// Bakiye hesabı için işaretli tutar (orijinal para biriminde).
    var signedAmount: Double { amount * type.signMultiplier }

    var hasPendingChanges: Bool {
        guard let syncedAt else { return true }
        return updatedAt > syncedAt
    }
}
