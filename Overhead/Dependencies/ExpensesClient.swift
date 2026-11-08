//
//  ExpensesClient.swift
//  Overhead
//
//  Created by Lorenzo Mazzarotto on 15/07/26.
//

import AccountKit
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

    var expenses: @Sendable (_ uid: String) async -> AsyncThrowingStream<[Expense], any Error> = { _ in
        AsyncThrowingStream { _ in }
    }

    var save: @Sendable (_ expense: Expense, _ uid: String) async throws -> Void
}

extension ExpensesClient: DependencyKey {
    static var liveValue: ExpensesClient {
        ExpensesClient(
            clearLocalData: {
                try await AccountStorage.shared.clearLocalData()
            },
            delete: { id, uid in
                try await AccountStorage.shared.delete(id: id, uid: uid)
            },
            expenses: { uid in
                await AccountStorage.shared.expenses(uid: uid)
            },
            save: { expense, uid in
                try await AccountStorage.shared.save(expense, uid: uid)
            }
        )
    }

    static var previewValue: ExpensesClient {
        ExpensesClient(
            clearLocalData: {},
            delete: { _, _ in },
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
            let amount = (data["amount"] as? Int).flatMap(Amount.init(value:)),
            let billingCycle = (data["billingCycle"] as? String).flatMap(BillingCycle.init(rawValue:)),
            let createdAt = data["createdAt"] as? Timestamp,
            let id = UUID(uuidString: documentID),
            let isActive = data["isActive"] as? Bool,
            let name = (data["name"] as? String).flatMap(ExpenseName.init(value:))
        else {
            logger.error("Skipping expense document \(documentID, privacy: .public) that failed to decode.")
            reportIssue("Skipping expense document \(documentID) that failed to decode.")
            return nil
        }
        self.init(
            amount: amount,
            billingCycle: billingCycle,
            createdAt: createdAt.dateValue(),
            id: id,
            isActive: isActive,
            name: name
        )
    }

    func documentData() -> [String: Any] {
        [
            "amount": amount.value,
            "billingCycle": billingCycle.rawValue,
            "createdAt": Timestamp(roundingToMicroseconds: createdAt),
            "isActive": isActive,
            "name": name.value,
        ]
    }
}

extension Timestamp {
    fileprivate convenience init(roundingToMicroseconds date: Date) {
        let microseconds = (date.timeIntervalSince1970 * 1_000_000).rounded()
        let seconds = (microseconds / 1_000_000).rounded(.down)
        self.init(
            seconds: Int64(seconds),
            nanoseconds: Int32(microseconds - seconds * 1_000_000) * 1000
        )
    }
}

private let logger = Logger(category: "ExpensesClient")
