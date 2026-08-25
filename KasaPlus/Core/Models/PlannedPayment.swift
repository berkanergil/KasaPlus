import Foundation
import SwiftData

/// Planlanan bir ödemenin durumu.
enum PlannedPaymentStatus: String, CaseIterable, Codable, Identifiable, Sendable {
    case pending
    case paid
    case cancelled

    var id: String { rawValue }

    var title: String {
        switch self {
        case .pending: return "Bekliyor"
        case .paid: return "Ödendi"
        case .cancelled: return "İptal"
        }
    }
}

/// İleri tarihli, henüz gerçekleşmemiş bir ödeme (kira, fatura, çek, tedarikçi vb.).
///
/// Vade yaklaşınca kullanıcıya bildirim gönderilir (1 hafta önce, 1 gün önce ve
/// vade günü). Vade günü gelen bildirimde "Ödedim" seçilirse kayıt otomatik olarak
/// bir **gider** işlemine dönüşür; "Ertele" seçilirse yeni vade tarihi sorulur.
@Model
final class PlannedPayment {
    @Attribute(.unique) var id: UUID

    /// Kullanıcının gördüğü başlık — örn. "Dükkân kirası", "Selçuk Ecza çeki"
    var title: String
    var amount: Double
    /// `Currency.rawValue`
    var currencyRaw: String
    /// Ödemenin yapılması gereken tarih ve saat (bildirimler bu saate göre kurulur)
    var dueDate: Date

    var categoryID: UUID
    /// `PaymentMethod.rawValue`
    var paymentMethodRaw: String
    /// Nakit dışı yöntemlerde bağlı banka
    var bankID: UUID?
    var note: String?

    /// `PlannedPaymentStatus.rawValue`
    var statusRaw: String
    /// Ödendi olarak işaretlendiğinde oluşturulan gider işleminin kimliği
    var paidTransactionID: UUID?
    var paidAt: Date?

    /// Bildirim gönderilsin mi?
    var reminderEnabled: Bool
    /// Kaç kez ertelendi (listede bilgi amaçlı gösterilir)
    var postponeCount: Int

    // MARK: - Çoklu kullanıcı / senkronizasyon alanları

    var userID: String
    var createdAt: Date
    var updatedAt: Date
    var isRemoved: Bool
    var syncedAt: Date?

    init(
        id: UUID = UUID(),
        title: String,
        amount: Double,
        currency: Currency = .TRY,
        dueDate: Date,
        categoryID: UUID,
        paymentMethod: PaymentMethod = .bankTransfer,
        bankID: UUID? = nil,
        note: String? = nil,
        status: PlannedPaymentStatus = .pending,
        paidTransactionID: UUID? = nil,
        paidAt: Date? = nil,
        reminderEnabled: Bool = true,
        postponeCount: Int = 0,
        userID: String,
        createdAt: Date = .now,
        updatedAt: Date = .now,
        isRemoved: Bool = false,
        syncedAt: Date? = nil
    ) {
        self.id = id
        self.title = title
        self.amount = amount
        self.currencyRaw = currency.rawValue
        self.dueDate = dueDate
        self.categoryID = categoryID
        self.paymentMethodRaw = paymentMethod.rawValue
        self.bankID = bankID
        self.note = note
        self.statusRaw = status.rawValue
        self.paidTransactionID = paidTransactionID
        self.paidAt = paidAt
        self.reminderEnabled = reminderEnabled
        self.postponeCount = postponeCount
        self.userID = userID
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.isRemoved = isRemoved
        self.syncedAt = syncedAt
    }
}

// MARK: - Tip güvenli erişimciler

extension PlannedPayment {
    var currency: Currency {
        get { Currency.from(rawValue: currencyRaw) }
        set { currencyRaw = newValue.rawValue }
    }

    var paymentMethod: PaymentMethod {
        get { PaymentMethod.from(rawValue: paymentMethodRaw) }
        set { paymentMethodRaw = newValue.rawValue }
    }

    var status: PlannedPaymentStatus {
        get { PlannedPaymentStatus(rawValue: statusRaw) ?? .pending }
        set { statusRaw = newValue.rawValue }
    }

    var hasPendingChanges: Bool {
        guard let syncedAt else { return true }
        return updatedAt > syncedAt
    }

    /// Vadeye kalan gün sayısı (negatifse gecikmiş).
    func daysRemaining(from reference: Date = .now, calendar: Calendar = .turkish) -> Int {
        let start = calendar.startOfDay(for: reference)
        let end = calendar.startOfDay(for: dueDate)
        return calendar.dateComponents([.day], from: start, to: end).day ?? 0
    }

    func isOverdue(reference: Date = .now) -> Bool {
        status == .pending && daysRemaining(from: reference) < 0
    }

    /// "3 gün kaldı" / "Bugün" / "2 gün gecikti" gibi kısa durum metni.
    func dueDescription(from reference: Date = .now) -> String {
        guard status == .pending else {
            if let paidAt { return "Ödendi · " + Formatters.shortDay.string(from: paidAt) }
            return status.title
        }
        let days = daysRemaining(from: reference)
        switch days {
        case 0: return "Bugün ödenecek"
        case 1: return "Yarın ödenecek"
        case let d where d > 1: return "\(d) gün kaldı"
        case -1: return "1 gün gecikti"
        default: return "\(abs(days)) gün gecikti"
        }
    }
}
