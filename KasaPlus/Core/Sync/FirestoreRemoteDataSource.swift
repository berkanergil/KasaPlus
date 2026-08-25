//
//  FirestoreRemoteDataSource.swift
//
//  Bu dosyanın tamamı `#if canImport(FirebaseFirestore)` ile korunmaktadır.
//  Firebase SDK projeye eklenmemişse dosya derlemede tamamen yok sayılır ve
//  uygulama yalnızca yerel depo ile çalışmaya devam eder.
//
//  Firebase'i etkinleştirmek için (detaylar: README.md → "Firebase Kurulumu"):
//    1. Xcode → File → Add Package Dependencies…
//       https://github.com/firebase/firebase-ios-sdk
//       Ürünler: FirebaseAuth, FirebaseFirestore
//    2. Firebase Console'dan indirdiğiniz `GoogleService-Info.plist` dosyasını
//       KasaPlus/Resources klasörüne sürükleyin (target: Kasa+).
//    3. Uygulamayı çalıştırın — başka kod değişikliği gerekmez.
//

import Foundation

#if canImport(FirebaseFirestore)
import FirebaseCore
import FirebaseFirestore

/// Firestore koleksiyon şeması:
///
///   users/{userID}/transactions/{transactionID}
///   users/{userID}/categories/{categoryID}
///   users/{userID}/banks/{bankID}
///   users/{userID}/plannedPayments/{plannedPaymentID}
///
/// Her doküman `updatedAt` (epoch saniye) taşır; senkronizasyon bu alana göre
/// artımlı (incremental) yapılır ve çakışmada son yazan kazanır.
struct FirestoreRemoteDataSource: RemoteDataSource {

    private var database: Firestore { Firestore.firestore() }

    var isConfigured: Bool {
        FirebaseApp.app() != nil
    }

    var statusDescription: String {
        isConfigured ? "Firebase bağlı" : "Firebase yapılandırması bulunamadı"
    }

    private func userDocument(_ userID: String) -> DocumentReference {
        database.collection("users").document(userID)
    }

    func fetchChanges(since date: Date?, userID: String) async throws -> RemoteSnapshot {
        guard isConfigured else { throw SyncError.notConfigured }
        guard !userID.isEmpty else { throw SyncError.notAuthenticated }

        let threshold = (date ?? Date(timeIntervalSince1970: 0)).timeIntervalSince1970
        var snapshot = RemoteSnapshot()

        let transactionQuery = userDocument(userID)
            .collection("transactions")
            .whereField("updatedAt", isGreaterThan: threshold)
        let transactionDocs = try await transactionQuery.getDocuments()
        snapshot.transactions = transactionDocs.documents.compactMap { TransactionDTO(firestoreData: $0.data()) }

        let categoryQuery = userDocument(userID)
            .collection("categories")
            .whereField("updatedAt", isGreaterThan: threshold)
        let categoryDocs = try await categoryQuery.getDocuments()
        snapshot.categories = categoryDocs.documents.compactMap { CategoryDTO(firestoreData: $0.data()) }

        let bankQuery = userDocument(userID)
            .collection("banks")
            .whereField("updatedAt", isGreaterThan: threshold)
        let bankDocs = try await bankQuery.getDocuments()
        snapshot.banks = bankDocs.documents.compactMap { BankDTO(firestoreData: $0.data()) }

        let plannedQuery = userDocument(userID)
            .collection("plannedPayments")
            .whereField("updatedAt", isGreaterThan: threshold)
        let plannedDocs = try await plannedQuery.getDocuments()
        snapshot.plannedPayments = plannedDocs.documents.compactMap { PlannedPaymentDTO(firestoreData: $0.data()) }

        return snapshot
    }

    func push(
        transactions: [TransactionDTO],
        categories: [CategoryDTO],
        banks: [BankDTO],
        plannedPayments: [PlannedPaymentDTO],
        userID: String
    ) async throws {
        guard isConfigured else { throw SyncError.notConfigured }
        guard !userID.isEmpty else { throw SyncError.notAuthenticated }
        guard !transactions.isEmpty || !categories.isEmpty
                || !banks.isEmpty || !plannedPayments.isEmpty else { return }

        // Firestore toplu yazma sınırı 500 işlemdir; parçalara bölerek yazıyoruz.
        let transactionRef = userDocument(userID).collection("transactions")
        let categoryRef = userDocument(userID).collection("categories")
        let bankRef = userDocument(userID).collection("banks")
        let plannedRef = userDocument(userID).collection("plannedPayments")

        var operations: [(DocumentReference, [String: Any])] = []
        operations += transactions.map { (transactionRef.document($0.id.uuidString), $0.firestoreData) }
        operations += categories.map { (categoryRef.document($0.id.uuidString), $0.firestoreData) }
        operations += banks.map { (bankRef.document($0.id.uuidString), $0.firestoreData) }
        operations += plannedPayments.map { (plannedRef.document($0.id.uuidString), $0.firestoreData) }

        for chunk in operations.chunked(into: 400) {
            let batch = database.batch()
            for (reference, data) in chunk {
                batch.setData(data, forDocument: reference, merge: true)
            }
            try await batch.commit()
        }
    }
}

private extension Array {
    func chunked(into size: Int) -> [[Element]] {
        guard size > 0 else { return [self] }
        return stride(from: 0, to: count, by: size).map {
            Array(self[$0 ..< Swift.min($0 + size, count)])
        }
    }
}

#endif
