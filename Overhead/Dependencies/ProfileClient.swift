//
//  ProfileClient.swift
//  Overhead
//
//  Created by Lorenzo Mazzarotto on 03/10/26.
//

import Dependencies
import DependenciesMacros
import FirebaseFirestore
import Foundation
import IssueReporting

@DependencyClient
struct ProfileClient: Sendable {
    var defaultCurrencyCode: @Sendable (_ uid: String) async -> AsyncThrowingStream<String?, any Error> = { _ in
        AsyncThrowingStream { _ in }
    }

    var delete: @Sendable (_ uid: String) async throws -> Void
    var saveDefaultCurrencyCode: @Sendable (_ currencyCode: String, _ uid: String) async throws -> Void
}

extension ProfileClient: DependencyKey {
    static var liveValue: ProfileClient {
        ProfileClient(
            defaultCurrencyCode: { uid in
                await FirestoreStorage.shared.defaultCurrencyCode(uid: uid)
            },
            delete: { uid in
                try await FirestoreStorage.shared.deleteProfile(uid: uid)
            },
            saveDefaultCurrencyCode: { currencyCode, uid in
                try await FirestoreStorage.shared.saveDefaultCurrencyCode(currencyCode, uid: uid)
            }
        )
    }

    static var previewValue: ProfileClient {
        ProfileClient(
            defaultCurrencyCode: { _ in
                AsyncThrowingStream { continuation in
                    continuation.yield(nil)
                }
            },
            delete: { _ in },
            saveDefaultCurrencyCode: { _, _ in }
        )
    }

    static var testValue: ProfileClient {
        ProfileClient()
    }
}

extension DependencyValues {
    var profileClient: ProfileClient {
        get { self[ProfileClient.self] }
        set { self[ProfileClient.self] = newValue }
    }
}

extension FirestoreStorage {
    func defaultCurrencyCode(uid: String) async -> AsyncThrowingStream<String?, any Error> {
        await waitForClearing()
        return AsyncThrowingStream { continuation in
            nonisolated(unsafe) let listener = profileDocument(uid: uid)
                .addSnapshotListener { snapshot, error in
                    if let error {
                        continuation.finish(throwing: error)
                        return
                    }
                    guard let snapshot else {
                        reportIssue("Profile listener reported neither a snapshot nor an error.")
                        return
                    }
                    continuation.yield(snapshot.get("defaultCurrencyCode") as? String)
                }
            continuation.onTermination = { _ in
                listener.remove()
            }
        }
    }

    func deleteProfile(uid: String) async throws {
        await waitForClearing()
        try await profileDocument(uid: uid).delete()
    }

    func saveDefaultCurrencyCode(_ currencyCode: String, uid: String) async throws {
        await waitForClearing()
        try await profileDocument(uid: uid).setData(["defaultCurrencyCode": currencyCode], merge: true)
    }
}

private func profileDocument(uid: String) -> DocumentReference {
    Firestore.firestore().collection("users").document(uid)
}
