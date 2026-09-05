import Foundation

// MARK: - Banka

struct BankDTO: Codable, Identifiable, Equatable, Sendable {
    let id: UUID
    let name: String
    let sortOrder: Int
    let isDefault: Bool
    let userID: String
    let createdAt: Date
    let updatedAt: Date
    let isDeleted: Bool

    init(_ model: Bank) {
        self.id = model.id
        self.name = model.name
        self.sortOrder = model.sortOrder
        self.isDefault = model.isDefault
        self.userID = model.userID
        self.createdAt = model.createdAt
        self.updatedAt = model.updatedAt
        self.isDeleted = model.isRemoved
    }

    var firestoreData: [String: Any] {
        [
            "id": id.uuidString,
            "name": name,
            "sortOrder": sortOrder,
            "isDefault": isDefault,
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
            let userID = data["userID"] as? String,
            let updatedValue = data["updatedAt"] as? Double
        else { return nil }

        self.id = id
        self.name = name
        self.sortOrder = data["sortOrder"] as? Int ?? 0
        self.isDefault = data["isDefault"] as? Bool ?? false
        self.userID = userID
        self.createdAt = Date(timeIntervalSince1970: data["createdAt"] as? Double ?? updatedValue)
        self.updatedAt = Date(timeIntervalSince1970: updatedValue)
        self.isDeleted = data["isDeleted"] as? Bool ?? false
    }
}

// MARK: - Planlanan ödeme

struct PlannedPaymentDTO: Codable, Identifiable, Equatable, Sendable {
    let id: UUID
    let title: String
    let amount: Double
    let currency: String
    let dueDate: Date
    let categoryID: UUID
    let paymentMethod: String
    let bankID: UUID?
    let note: String?
    let status: String
    let paidTransactionID: UUID?
    let paidAt: Date?
    let reminderEnabled: Bool
    let postponeCount: Int
    let recurrenceGroupID: UUID?
    let recurrenceFrequency: String?
    let recurrenceEndDate: Date?
    let userID: String
    let createdAt: Date
    let updatedAt: Date
    let isDeleted: Bool

    init(_ model: PlannedPayment) {
        self.id = model.id
        self.title = model.title
        self.amount = model.amount
        self.currency = model.currencyRaw
        self.dueDate = model.dueDate
        self.categoryID = model.categoryID
        self.paymentMethod = model.paymentMethodRaw
        self.bankID = model.bankID
        self.note = model.note
        self.status = model.statusRaw
        self.paidTransactionID = model.paidTransactionID
        self.paidAt = model.paidAt
        self.reminderEnabled = model.reminderEnabled
        self.postponeCount = model.postponeCount
        self.recurrenceGroupID = model.recurrenceGroupID
        self.recurrenceFrequency = model.recurrenceFrequencyRaw
        self.recurrenceEndDate = model.recurrenceEndDate
        self.userID = model.userID
        self.createdAt = model.createdAt
        self.updatedAt = model.updatedAt
        self.isDeleted = model.isRemoved
    }

    var firestoreData: [String: Any] {
        var data: [String: Any] = [
            "id": id.uuidString,
            "title": title,
            "amount": amount,
            "currency": currency,
            "dueDate": dueDate.timeIntervalSince1970,
            "categoryID": categoryID.uuidString,
            "paymentMethod": paymentMethod,
            "status": status,
            "reminderEnabled": reminderEnabled,
            "postponeCount": postponeCount,
            "userID": userID,
            "createdAt": createdAt.timeIntervalSince1970,
            "updatedAt": updatedAt.timeIntervalSince1970,
            "isDeleted": isDeleted
        ]
        if let bankID { data["bankID"] = bankID.uuidString }
        if let note { data["note"] = note }
        if let paidTransactionID { data["paidTransactionID"] = paidTransactionID.uuidString }
        if let paidAt { data["paidAt"] = paidAt.timeIntervalSince1970 }
        if let recurrenceGroupID { data["recurrenceGroupID"] = recurrenceGroupID.uuidString }
        if let recurrenceFrequency { data["recurrenceFrequency"] = recurrenceFrequency }
        if let recurrenceEndDate { data["recurrenceEndDate"] = recurrenceEndDate.timeIntervalSince1970 }
        return data
    }

    init?(firestoreData data: [String: Any]) {
        guard
            let idString = data["id"] as? String, let id = UUID(uuidString: idString),
            let title = data["title"] as? String,
            let amount = data["amount"] as? Double,
            let dueValue = data["dueDate"] as? Double,
            let categoryIDString = data["categoryID"] as? String,
            let categoryID = UUID(uuidString: categoryIDString),
            let userID = data["userID"] as? String,
            let updatedValue = data["updatedAt"] as? Double
        else { return nil }

        self.id = id
        self.title = title
        self.amount = amount
        self.currency = data["currency"] as? String ?? Currency.TRY.rawValue
        self.dueDate = Date(timeIntervalSince1970: dueValue)
        self.categoryID = categoryID
        self.paymentMethod = data["paymentMethod"] as? String ?? PaymentMethod.bankTransfer.rawValue
        self.bankID = (data["bankID"] as? String).flatMap(UUID.init(uuidString:))
        self.note = data["note"] as? String
        self.status = data["status"] as? String ?? PlannedPaymentStatus.pending.rawValue
        self.paidTransactionID = (data["paidTransactionID"] as? String).flatMap(UUID.init(uuidString:))
        self.paidAt = (data["paidAt"] as? Double).map { Date(timeIntervalSince1970: $0) }
        self.reminderEnabled = data["reminderEnabled"] as? Bool ?? true
        self.postponeCount = data["postponeCount"] as? Int ?? 0
        self.recurrenceGroupID = (data["recurrenceGroupID"] as? String).flatMap(UUID.init(uuidString:))
        self.recurrenceFrequency = data["recurrenceFrequency"] as? String
        self.recurrenceEndDate = (data["recurrenceEndDate"] as? Double).map { Date(timeIntervalSince1970: $0) }
        self.userID = userID
        self.createdAt = Date(timeIntervalSince1970: data["createdAt"] as? Double ?? updatedValue)
        self.updatedAt = Date(timeIntervalSince1970: updatedValue)
        self.isDeleted = data["isDeleted"] as? Bool ?? false
    }
}
