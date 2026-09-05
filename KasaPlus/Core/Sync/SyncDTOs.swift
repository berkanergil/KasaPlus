import Foundation

/// Yerel model ile uzak depo (Firestore) arasında taşınan düz veri yapıları.
/// Modeller doğrudan taşınmaz — böylece uzak şema değişse bile yerel model korunur.

struct TransactionDTO: Codable, Identifiable, Equatable, Sendable {
    let id: UUID
    let amount: Double
    let date: Date
    let type: String
    let currency: String
    let paymentMethod: String
    let categoryID: UUID
    let bankID: UUID?
    let note: String?
    let recurrenceGroupID: UUID?
    let recurrenceFrequency: String?
    let recurrenceEndDate: Date?
    let userID: String
    let createdAt: Date
    let updatedAt: Date
    let isDeleted: Bool

    init(_ model: FinanceTransaction) {
        self.id = model.id
        self.amount = model.amount
        self.date = model.date
        self.type = model.typeRaw
        self.currency = model.currencyRaw
        self.paymentMethod = model.paymentMethodRaw
        self.categoryID = model.categoryID
        self.bankID = model.bankID
        self.note = model.note
        self.recurrenceGroupID = model.recurrenceGroupID
        self.recurrenceFrequency = model.recurrenceFrequencyRaw
        self.recurrenceEndDate = model.recurrenceEndDate
        self.userID = model.userID
        self.createdAt = model.createdAt
        self.updatedAt = model.updatedAt
        self.isDeleted = model.isRemoved
    }

    init(
        id: UUID, amount: Double, date: Date, type: String, currency: String,
        paymentMethod: String, categoryID: UUID, bankID: UUID?, note: String?, userID: String,
        createdAt: Date, updatedAt: Date, isDeleted: Bool,
        recurrenceGroupID: UUID? = nil, recurrenceFrequency: String? = nil, recurrenceEndDate: Date? = nil
    ) {
        self.id = id
        self.amount = amount
        self.date = date
        self.type = type
        self.currency = currency
        self.paymentMethod = paymentMethod
        self.categoryID = categoryID
        self.bankID = bankID
        self.note = note
        self.recurrenceGroupID = recurrenceGroupID
        self.recurrenceFrequency = recurrenceFrequency
        self.recurrenceEndDate = recurrenceEndDate
        self.userID = userID
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.isDeleted = isDeleted
    }

    /// Firestore'a yazılabilir sözlük gösterimi.
    var firestoreData: [String: Any] {
        var data: [String: Any] = [
            "id": id.uuidString,
            "amount": amount,
            "date": date.timeIntervalSince1970,
            "type": type,
            "currency": currency,
            "paymentMethod": paymentMethod,
            "categoryID": categoryID.uuidString,
            "userID": userID,
            "createdAt": createdAt.timeIntervalSince1970,
            "updatedAt": updatedAt.timeIntervalSince1970,
            "isDeleted": isDeleted
        ]
        if let note { data["note"] = note }
        if let bankID { data["bankID"] = bankID.uuidString }
        if let recurrenceGroupID { data["recurrenceGroupID"] = recurrenceGroupID.uuidString }
        if let recurrenceFrequency { data["recurrenceFrequency"] = recurrenceFrequency }
        if let recurrenceEndDate { data["recurrenceEndDate"] = recurrenceEndDate.timeIntervalSince1970 }
        return data
    }

    init?(firestoreData data: [String: Any]) {
        guard
            let idString = data["id"] as? String, let id = UUID(uuidString: idString),
            let amount = data["amount"] as? Double,
            let dateValue = data["date"] as? Double,
            let type = data["type"] as? String,
            let categoryIDString = data["categoryID"] as? String,
            let categoryID = UUID(uuidString: categoryIDString),
            let userID = data["userID"] as? String,
            let updatedValue = data["updatedAt"] as? Double
        else { return nil }

        self.id = id
        self.amount = amount
        self.date = Date(timeIntervalSince1970: dateValue)
        self.type = type
        self.currency = data["currency"] as? String ?? Currency.TRY.rawValue
        self.paymentMethod = data["paymentMethod"] as? String ?? PaymentMethod.cash.rawValue
        self.categoryID = categoryID
        self.bankID = (data["bankID"] as? String).flatMap(UUID.init(uuidString:))
        self.note = data["note"] as? String
        self.recurrenceGroupID = (data["recurrenceGroupID"] as? String).flatMap(UUID.init(uuidString:))
        self.recurrenceFrequency = data["recurrenceFrequency"] as? String
        self.recurrenceEndDate = (data["recurrenceEndDate"] as? Double).map { Date(timeIntervalSince1970: $0) }
        self.userID = userID
        self.createdAt = Date(timeIntervalSince1970: data["createdAt"] as? Double ?? updatedValue)
        self.updatedAt = Date(timeIntervalSince1970: updatedValue)
        self.isDeleted = data["isDeleted"] as? Bool ?? false
    }
}

struct CategoryDTO: Codable, Identifiable, Equatable, Sendable {
    let id: UUID
    let name: String
    let iconName: String
    let colorHex: String
    let type: String
    let isDefault: Bool
    let sortOrder: Int
    let userID: String
    let createdAt: Date
    let updatedAt: Date
    let isDeleted: Bool

    init(_ model: Category) {
        self.id = model.id
        self.name = model.name
        self.iconName = model.iconName
        self.colorHex = model.colorHex
        self.type = model.typeRaw
        self.isDefault = model.isDefault
        self.sortOrder = model.sortOrder
        self.userID = model.userID
        self.createdAt = model.createdAt
        self.updatedAt = model.updatedAt
        self.isDeleted = model.isRemoved
    }

    init(
        id: UUID, name: String, iconName: String, colorHex: String, type: String,
        isDefault: Bool, sortOrder: Int, userID: String,
        createdAt: Date, updatedAt: Date, isDeleted: Bool
    ) {
        self.id = id
        self.name = name
        self.iconName = iconName
        self.colorHex = colorHex
        self.type = type
        self.isDefault = isDefault
        self.sortOrder = sortOrder
        self.userID = userID
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.isDeleted = isDeleted
    }

    var firestoreData: [String: Any] {
        [
            "id": id.uuidString,
            "name": name,
            "iconName": iconName,
            "colorHex": colorHex,
            "type": type,
            "isDefault": isDefault,
            "sortOrder": sortOrder,
            "userID": userID,
            "createdAt": createdAt.timeIntervalSince1970,
            "updatedAt": updatedAt.timeIntervalSince1970,
            "isDeleted": isDeleted
        ]
    }

    init?(firestoreData data: [String: Any]) {
        guard
            let idString = data["id"] as? String, let id = UUID(uuidString: idString),
            let name = data["name"] as? String,
            let type = data["type"] as? String,
            let userID = data["userID"] as? String,
            let updatedValue = data["updatedAt"] as? Double
        else { return nil }

        self.id = id
        self.name = name
        self.iconName = data["iconName"] as? String ?? "tag.fill"
        self.colorHex = data["colorHex"] as? String ?? "#889096"
        self.type = type
        self.isDefault = data["isDefault"] as? Bool ?? false
        self.sortOrder = data["sortOrder"] as? Int ?? 0
        self.userID = userID
        self.createdAt = Date(timeIntervalSince1970: data["createdAt"] as? Double ?? updatedValue)
        self.updatedAt = Date(timeIntervalSince1970: updatedValue)
        self.isDeleted = data["isDeleted"] as? Bool ?? false
    }
}

/// Uzak taraftan çekilen değişiklik kümesi.
struct RemoteSnapshot: Sendable {
    var transactions: [TransactionDTO] = []
    var categories: [CategoryDTO] = []
    var banks: [BankDTO] = []
    var plannedPayments: [PlannedPaymentDTO] = []

    var isEmpty: Bool {
        transactions.isEmpty && categories.isEmpty && banks.isEmpty && plannedPayments.isEmpty
    }
}
