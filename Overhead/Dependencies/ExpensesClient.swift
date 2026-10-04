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

extension Expense {
    init?(documentID: String, data: [String: Any]) {
        guard
            let amountInCents = data["amountInCents"] as? Int,
            let billingCycle = (data["billingCycle"] as? String).flatMap(BillingCycle.init(rawValue:)),
            let createdAt = data["createdAt"] as? Timestamp,
            let id = UUID(uuidString: documentID),
            let isActive = data["isActive"] as? Bool,
            let name = data["name"] as? String
        else {
            logger.error("Skipping expense document \(documentID, privacy: .public) that failed to decode.")
            reportIssue("Skipping expense document \(documentID) that failed to decode.")
            return nil
        }
        self.init(
            amount: Decimal(cents: amountInCents),
            billingCycle: billingCycle,
            createdAt: createdAt.dateValue(),
            id: id,
            isActive: isActive,
            name: name
        )
    }

    func documentData() throws -> [String: Any] {
        guard let amountInCents = amount.cents else {
            reportIssue("Expense \(id) has an amount that cents cannot represent.")
            throw InexactAmountError()
        }
        return [
            "amountInCents": amountInCents,
            "billingCycle": billingCycle.rawValue,
            "createdAt": Timestamp(date: createdAt),
            "isActive": isActive,
            "name": name,
        ]
    }
}

private struct InexactAmountError: Error {}

private let logger = Logger(category: "ExpensesClient")
