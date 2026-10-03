//
//  ExpensesClient.swift
//  Overhead
//
//  Created by Lorenzo Mazzarotto on 15/07/26.
//

import Dependencies
import DependenciesMacros
import FirebaseFirestore
import Foundation
import IssueReporting
import os

@DependencyClient
struct ExpensesClient: Sendable {
    var clearLocalData: @Sendable () async throws -> Void
    var delete: @Sendable (_ id: Expense.ID, _ uid: String) async throws -> Void
    var deleteAll: @Sendable (_ uid: String) async throws -> Void

    var expenses: @Sendable (_ uid: String) async -> AsyncThrowingStream<[Expense], any Error> = { _ in
        AsyncThrowingStream { _ in }
    }

    var save: @Sendable (_ expense: Expense, _ uid: String) async throws -> Void
}

extension ExpensesClient: DependencyKey {
    static var liveValue: ExpensesClient {
        ExpensesClient(
            clearLocalData: {
                try await FirestoreStorage.shared.clearLocalData()
            },
            delete: { id, uid in
                try await FirestoreStorage.shared.delete(id: id, uid: uid)
            },
            deleteAll: { uid in
                try await FirestoreStorage.shared.deleteAll(uid: uid)
            },
            expenses: { uid in
                await FirestoreStorage.shared.expenses(uid: uid)
            },
            save: { expense, uid in
                try await FirestoreStorage.shared.save(expense, uid: uid)
            }
        )
    }

    static var previewValue: ExpensesClient {
        ExpensesClient(
            clearLocalData: {},
            delete: { _, _ in },
            deleteAll: { _ in },
            expenses: { _ in
                AsyncThrowingStream { continuation in
                    continuation.yield(Expense.mocks)
                }
            },
            save: { _, _ in }
        )
    }

    static var testValue: ExpensesClient {
        ExpensesClient()
    }
}

extension DependencyValues {
    var expensesClient: ExpensesClient {
        get { self[ExpensesClient.self] }
        set { self[ExpensesClient.self] = newValue }
    }
}

private actor FirestoreStorage {
    static let shared = FirestoreStorage()

    private var clearing: Task<Void, any Error>?

    func clearLocalData() async throws {
        if let clearing {
            return try await clearing.value
        }
        let clearing = Task {
            let firestore = Firestore.firestore()
            try await firestore.terminate()
            try await firestore.clearPersistence()
        }
        self.clearing = clearing
        defer { self.clearing = nil }
        try await clearing.value
    }

    func delete(id: Expense.ID, uid: String) async throws {
        await waitForClearing()
        try await expensesCollection(uid: uid).document(id.uuidString).delete()
    }

    func deleteAll(uid: String) async throws {
        await waitForClearing()
        while true {
            try Task.checkCancellation()
            let snapshot = try await expensesCollection(uid: uid).limit(to: 500).getDocuments()
            guard !snapshot.documents.isEmpty else { return }
            let batch = Firestore.firestore().batch()
            for document in snapshot.documents {
                batch.deleteDocument(document.reference)
            }
            try await batch.commit()
        }
    }

    func expenses(uid: String) async -> AsyncThrowingStream<[Expense], any Error> {
        await waitForClearing()
        return AsyncThrowingStream { continuation in
            nonisolated(unsafe) let listener = expensesCollection(uid: uid)
                .order(by: "createdAt", descending: true)
                .addSnapshotListener { snapshot, error in
                    if let error {
                        continuation.finish(throwing: error)
                        return
                    }
                    guard let snapshot else {
                        reportIssue("Expenses listener reported neither a snapshot nor an error.")
                        return
                    }
                    continuation.yield(snapshot.documents.compactMap(Expense.init(document:)))
                }
            continuation.onTermination = { _ in
                listener.remove()
            }
        }
    }

    func save(_ expense: Expense, uid: String) async throws {
        await waitForClearing()
        try await expensesCollection(uid: uid).document(expense.id.uuidString).setData(expense.documentData())
    }

    private func waitForClearing() async {
        _ = try? await clearing?.value
    }
}

private func expensesCollection(uid: String) -> CollectionReference {
    Firestore.firestore().collection("users").document(uid).collection("expenses")
}

extension Expense {
    fileprivate init?(document: QueryDocumentSnapshot) {
        let data = document.data()
        guard
            let amountMinorUnits = data["amountMinorUnits"] as? Int,
            let billingCycle = (data["billingCycle"] as? String).flatMap(BillingCycle.init(rawValue:)),
            let createdAt = data["createdAt"] as? Timestamp,
            let currencyCode = data["currencyCode"] as? String,
            let id = UUID(uuidString: document.documentID),
            let name = data["name"] as? String
        else {
            logger.error("Skipping expense document \(document.documentID, privacy: .public) that failed to decode.")
            reportIssue("Skipping expense document \(document.documentID) that failed to decode.")
            return nil
        }
        self.init(
            amount: Decimal(minorUnits: amountMinorUnits, currencyCode: currencyCode),
            billingCycle: billingCycle,
            createdAt: createdAt.dateValue(),
            currencyCode: currencyCode,
            id: id,
            name: name
        )
    }

    fileprivate func documentData() throws -> [String: Any] {
        guard let amountMinorUnits = amount.minorUnits(currencyCode: currencyCode) else {
            reportIssue("Expense \(id) has an amount that \(currencyCode) cannot represent.")
            throw InexactAmountError()
        }
        return [
            "amountMinorUnits": amountMinorUnits,
            "billingCycle": billingCycle.rawValue,
            "createdAt": Timestamp(date: createdAt),
            "currencyCode": currencyCode,
            "name": name,
        ]
    }
}

private struct InexactAmountError: Error {}

private let logger = Logger(category: "ExpensesClient")
