//
//  FirestoreStorage.swift
//  Overhead
//
//  Created by Lorenzo Mazzarotto on 04/10/26.
//

import ConcurrencyExtras
import FirebaseFirestore
import Foundation
import IssueReporting

actor FirestoreStorage {
    static let shared = FirestoreStorage()

    private var clearing: Task<Void, any Error>?

    func budget(uid: String) async -> AsyncThrowingStream<BudgetSnapshot, any Error> {
        await waitForClearing()
        return AsyncThrowingStream { continuation in
            let delivered = LockIsolated<(data: NSDictionary?, isKnown: Bool)?>(nil)
            let registration = ListenerRegistrationBox()
            let listener = budgetDocument(uid: uid)
                .addSnapshotListener(includeMetadataChanges: true) { snapshot, error in
                    if let error {
                        registration.remove()
                        continuation.finish(throwing: error)
                        return
                    }
                    guard let snapshot else {
                        reportIssue("Budget listener reported neither a snapshot nor an error.")
                        return
                    }
                    let data = snapshot.data()
                    let isConfirmed = snapshot.exists || !snapshot.metadata.isFromCache
                    nonisolated(unsafe) let current = data.map(NSDictionary.init(dictionary:))
                    let isKnown = delivered.withValue { delivered -> Bool? in
                        let isKnown = isConfirmed || delivered?.isKnown == true
                        if let delivered, delivered.data == current, delivered.isKnown == isKnown {
                            return nil
                        }
                        delivered = (current, isKnown)
                        return isKnown
                    }
                    guard let isKnown else { return }
                    continuation.yield(isKnown ? .known(data.flatMap(Budget.init(data:))) : .unknown)
                }
            registration.set(listener)
            continuation.onTermination = { _ in
                registration.remove()
            }
        }
    }

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

    func deleteBudget(uid: String) async throws {
        await waitForClearing()
        try await budgetDocument(uid: uid).delete()
    }

    func expenses(uid: String) async -> AsyncThrowingStream<[Expense], any Error> {
        await waitForClearing()
        return AsyncThrowingStream { continuation in
            nonisolated(unsafe) let listener = expensesCollection(uid: uid)
                .addSnapshotListener { snapshot, error in
                    if let error {
                        continuation.finish(throwing: error)
                        return
                    }
                    guard let snapshot else {
                        reportIssue("Expenses listener reported neither a snapshot nor an error.")
                        return
                    }
                    continuation.yield(
                        snapshot.documents.compactMap { Expense(documentID: $0.documentID, data: $0.data()) }
                    )
                }
            continuation.onTermination = { _ in
                listener.remove()
            }
        }
    }

    func removeInvestment(uid: String) async throws {
        await waitForClearing()
        try await budgetDocument(uid: uid).updateData([BudgetField.investment: FieldValue.delete()])
    }

    func save(_ expense: Expense, uid: String) async throws {
        await waitForClearing()
        try await expensesCollection(uid: uid).document(expense.id.uuidString).setData(expense.documentData())
    }

    func saveIncome(_ income: Decimal, removingInvestment: Bool, uid: String) async throws {
        await waitForClearing()
        var data: [String: Any] = [BudgetField.income: try BudgetField.cents(of: income)]
        if removingInvestment {
            data[BudgetField.investment] = FieldValue.delete()
        }
        try await budgetDocument(uid: uid).setData(data, merge: true)
    }

    func saveInvestment(_ investment: Decimal, uid: String) async throws {
        await waitForClearing()
        try await budgetDocument(uid: uid)
            .setData([BudgetField.investment: try BudgetField.cents(of: investment)], merge: true)
    }

    private func waitForClearing() async {
        _ = try? await clearing?.value
    }
}

private final class ListenerRegistrationBox: @unchecked Sendable {
    private let lock = NSLock()
    private var registration: (any ListenerRegistration)?

    func remove() {
        lock.withLock { registration }?.remove()
    }

    func set(_ registration: any ListenerRegistration) {
        lock.withLock { self.registration = registration }
    }
}

private func budgetDocument(uid: String) -> DocumentReference {
    Firestore.firestore().collection("users").document(uid)
}

private func expensesCollection(uid: String) -> CollectionReference {
    Firestore.firestore().collection("users").document(uid).collection("expenses")
}
