//
//  FirestoreStorageTests.swift
//  OverheadTests
//
//  Created by Lorenzo Mazzarotto on 04/10/26.
//

import ConcurrencyExtras
import CustomDump
import FirebaseAuth
import FirebaseCore
import FirebaseFirestore
import Foundation
import Testing

@testable import Overhead

extension BaseSuite.IntegrationSuite {
    @Suite
    struct FirestoreStorageTests {
        @Test
        func aMissingBudgetArrivesAsNil() async throws {
            let uid = try await FirebaseEmulators.signIn()
            let budgets = Recording(await FirestoreStorage.shared.budget(uid: uid))
            defer { budgets.cancel() }

            try await budgets.wait { $0.map(\.budget) == [nil] }
        }

        @Test
        func aMissingBudgetIsMarkedAsCachedWhileOffline() async throws {
            let uid = try await FirebaseEmulators.signIn()
            try await Firestore.firestore().disableNetwork()
            let budgets = Recording(await FirestoreStorage.shared.budget(uid: uid))
            defer { budgets.cancel() }

            try await budgets.wait { $0 == [BudgetSnapshot(budget: nil, isFromCache: true)] }

            try await Firestore.firestore().enableNetwork()
            try await budgets.wait { $0.last == BudgetSnapshot(budget: nil, isFromCache: false) }
        }

        @Test
        func aSavedBudgetArrivesOnceAndADeletedBudgetBecomesNil() async throws {
            let uid = try await FirebaseEmulators.signIn()
            let budgets = Recording(await FirestoreStorage.shared.budget(uid: uid))
            defer { budgets.cancel() }
            try await budgets.wait { $0.map(\.budget) == [nil] }

            try await FirestoreStorage.shared.save(Budget.mock, uid: uid)
            try await budgets.wait { $0.map(\.budget) == [nil, .mock] }

            let raise = Budget(income: 3500, investment: nil)
            try await FirestoreStorage.shared.save(raise, uid: uid)
            try await budgets.wait { $0.map(\.budget) == [nil, .mock, raise] }

            try await FirestoreStorage.shared.deleteBudget(uid: uid)
            try await budgets.wait { $0.map(\.budget) == [nil, .mock, raise, nil] }

            let marker = Budget(income: 1, investment: nil)
            try await FirestoreStorage.shared.save(marker, uid: uid)
            try await budgets.wait { $0.last?.budget == marker }
            expectNoDifference(budgets.values.map(\.budget), [nil, .mock, raise, nil, marker])
        }

        @Test
        func aBudgetRemovedOfflineBecomesNilAtOnce() async throws {
            let uid = try await FirebaseEmulators.signIn()
            try await FirestoreStorage.shared.save(Budget.mock, uid: uid)
            let budgets = Recording(await FirestoreStorage.shared.budget(uid: uid))
            defer { budgets.cancel() }
            try await budgets.wait { $0.last == BudgetSnapshot(budget: .mock, isFromCache: false) }

            try await Firestore.firestore().disableNetwork()
            let deletion = Task { try await FirestoreStorage.shared.deleteBudget(uid: uid) }

            try await budgets.wait { $0.last == BudgetSnapshot(budget: nil, isFromCache: true) }
            try await Firestore.firestore().enableNetwork()
            try await deletion.value
        }

        @Test
        func theRulesRefuseAnotherUsersBudget() async throws {
            let owner = try await FirebaseEmulators.signIn()
            try await FirestoreStorage.shared.save(Budget.mock, uid: owner)
            _ = try await FirebaseEmulators.signIn()

            let error = await #expect(throws: NSError.self) {
                try await FirestoreStorage.shared.save(Budget(income: 1, investment: nil), uid: owner)
            }
            expectNoDifference(error?.code, FirestoreErrorCode.permissionDenied.rawValue)

            let budgets = Recording(await FirestoreStorage.shared.budget(uid: owner))
            defer { budgets.cancel() }
            let failure = try await budgets.waitForFailure() as NSError
            expectNoDifference(failure.code, FirestoreErrorCode.permissionDenied.rawValue)
            expectNoDifference(budgets.values.map(\.budget), [])
        }

        @Test
        func savedExpensesArriveAndDeleteAllRemovesThem() async throws {
            let uid = try await FirebaseEmulators.signIn()
            let expenses = Recording(await FirestoreStorage.shared.expenses(uid: uid))
            defer { expenses.cancel() }
            try await expenses.wait { $0.last == [] }

            for expense in Expense.mocks {
                try await FirestoreStorage.shared.save(expense, uid: uid)
            }
            try await expenses.wait { $0.last?.count == Expense.mocks.count }
            expectNoDifference(
                expenses.values.last?.sorted { $0.id.uuidString < $1.id.uuidString },
                Expense.mocks
            )

            try await FirestoreStorage.shared.deleteAll(uid: uid)
            try await expenses.wait { $0.last == [] }
        }

        @Test(arguments: 0 ..< 20)
        func anExpenseCanBeEditedAfterItIsReadBack(seed: Int) async throws {
            let uid = try await FirebaseEmulators.signIn()
            let expense = Expense(
                amount: 10,
                billingCycle: .monthly,
                createdAt: Date(timeIntervalSince1970: 1_751_000_000 + Double(seed) * 0.123_456_789 + 0.000_000_7),
                id: Expense.gym.id,
                isActive: true,
                name: "Gym"
            )
            try await FirestoreStorage.shared.save(expense, uid: uid)
            let document = try await Firestore.firestore()
                .collection("users").document(uid).collection("expenses").document(expense.id.uuidString)
                .getDocument(source: .server)

            var stored = try #require(Expense(documentID: document.documentID, data: document.data() ?? [:]))
            stored.name = "Gym Plus"
            try await FirestoreStorage.shared.save(stored, uid: uid)
        }
    }
}

private final class Recording<Element: Sendable>: Sendable {
    private let failure = LockIsolated<(any Error)?>(nil)
    private let recorded = LockIsolated<[Element]>([])
    private let task = LockIsolated<Task<Void, Never>?>(nil)

    init(_ stream: AsyncThrowingStream<Element, any Error>) {
        task.setValue(
            Task { [failure, recorded] in
                do {
                    for try await value in stream {
                        recorded.withValue { $0.append(value) }
                    }
                } catch {
                    failure.setValue(error)
                }
            }
        )
    }

    var values: [Element] { recorded.value }

    func cancel() {
        task.value?.cancel()
    }

    func wait(
        timeout: Duration = .seconds(10),
        sourceLocation: SourceLocation = #_sourceLocation,
        until condition: ([Element]) -> Bool
    ) async throws {
        let deadline = ContinuousClock.now.advanced(by: timeout)
        while !condition(recorded.value) {
            guard ContinuousClock.now < deadline else {
                Issue.record(
                    "Timed out. Recorded: \(String(customDumping: recorded.value))", sourceLocation: sourceLocation)
                throw TimeoutError()
            }
            try await Task.sleep(for: .milliseconds(20))
        }
    }

    func waitForFailure(
        timeout: Duration = .seconds(10),
        sourceLocation: SourceLocation = #_sourceLocation
    ) async throws -> any Error {
        let deadline = ContinuousClock.now.advanced(by: timeout)
        while true {
            if let failure = failure.value { return failure }
            guard ContinuousClock.now < deadline else {
                Issue.record("Timed out waiting for a failure.", sourceLocation: sourceLocation)
                throw TimeoutError()
            }
            try await Task.sleep(for: .milliseconds(20))
        }
    }
}

private struct TimeoutError: Error {}

extension BaseSuite {
    @Suite(.enabled(if: FirebaseEmulators.isAvailable), .timeLimit(.minutes(1)))
    struct IntegrationSuite {}
}

enum FirebaseEmulators {
    static let isAvailable = ProcessInfo.processInfo.environment["FIREBASE_EMULATORS"] == "1"

    private static let configuration: Void = {
        let options = FirebaseOptions(googleAppID: "1:123456789000:ios:0000000000000000", gcmSenderID: "123456789000")
        options.apiKey = "AIzaDemoKeyForTheLocalEmulatorsOnly0000"
        options.projectID = "demo-overhead"
        FirebaseApp.configure(options: options)
        Auth.auth().useEmulator(withHost: "127.0.0.1", port: 9099)
        useFirestoreEmulator()
    }()

    static func signOut() throws {
        try Auth.auth().signOut()
    }

    static func signIn() async throws -> String {
        configuration
        try? Auth.auth().signOut()
        try await FirestoreStorage.shared.clearLocalData()
        useFirestoreEmulator()
        return try await Auth.auth().signInAnonymously().user.uid
    }

    private static func useFirestoreEmulator() {
        let settings = Firestore.firestore().settings
        settings.host = "127.0.0.1:8080"
        settings.isSSLEnabled = false
        Firestore.firestore().settings = settings
    }
}
