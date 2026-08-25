//
//  FirebaseAuthBridge.swift
//
//  Firebase Auth yalnızca SDK projeye eklendiğinde derlenir.
//  Eklenmediğinde bu dosya tamamen yok sayılır ve Apple girişi
//  yerel (Firebase'siz) modda çalışmaya devam eder.
//

import Foundation

#if canImport(FirebaseAuth)
import FirebaseAuth

enum FirebaseAuthBridge {

    /// Apple'dan alınan kimlik belirtecini Firebase oturumuna çevirir.
    /// - Returns: Firestore güvenlik kurallarında kullanılacak Firebase UID.
    @MainActor
    static func signIn(idToken: String, rawNonce: String, fullName: PersonNameComponents?) async throws -> String {
        let credential = OAuthProvider.appleCredential(
            withIDToken: idToken,
            rawNonce: rawNonce,
            fullName: fullName
        )
        let result = try await Auth.auth().signIn(with: credential)

        // İsim yalnızca ilk girişte gelir; Firebase profiline bir kez yazıyoruz.
        if let fullName, result.user.displayName == nil {
            let formatter = PersonNameComponentsFormatter()
            let name = formatter.string(from: fullName).trimmingCharacters(in: .whitespaces)
            if !name.isEmpty {
                let request = result.user.createProfileChangeRequest()
                request.displayName = name
                try? await request.commitChanges()
            }
        }
        return result.user.uid
    }

    @MainActor
    static func signOut() {
        try? Auth.auth().signOut()
    }

    static var currentUID: String? {
        Auth.auth().currentUser?.uid
    }
}
#endif
