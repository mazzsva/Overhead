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

            try await budgets.wait { $0 == [.known(nil)] }
        }

        @Test
        func aMissingBudgetIsUnknownWhileOfflineBeforeAnySync() async throws {
            let uid = try await FirebaseEmulators.signIn()
            try await Firestore.firestore().disableNetwork()
            let budgets = Recording(await FirestoreStorage.shared.budget(uid: uid))
            defer { budgets.cancel() }

            try await budgets.wait { $0 == [.unknown] }

            try await Firestore.firestore().enableNetwork()
            try await budgets.wait { $0.last == .known(nil) }
        }

        @Test
        func aSavedBudgetArrivesOnceAndADeletedBudgetBecomesNil() async throws {
            let uid = try await FirebaseEmulators.signIn()
            let budgets = Recording(await FirestoreStorage.shared.budget(uid: uid))
            defer { budgets.cancel() }
            try await budgets.wait { $0 == [.known(nil)] }

            let income = try #require(Budget(income: 3000, investment: nil))
            try await FirestoreStorage.shared.saveIncome(3000, removingInvestment: false, uid: uid)
            try await budgets.wait { $0 == [.known(nil), .known(income)] }

            try await FirestoreStorage.shared.saveInvestment(450, uid: uid)
            try await budgets.wait { $0 == [.known(nil), .known(income), .known(.mock)] }

            try await FirestoreStorage.shared.deleteBudget(uid: uid)
            try await budgets.wait { $0 == [.known(nil), .known(income), .known(.mock), .known(nil)] }

            let marker = try #require(Budget(income: 1, investment: nil))
            try await FirestoreStorage.shared.saveIncome(1, removingInvestment: false, uid: uid)
            try await budgets.wait { $0.last == .known(marker) }
            expectNoDifference(
                budgets.values, [.known(nil), .known(income), .known(.mock), .known(nil), .known(marker)])
        }

        @Test
        func aBudgetRemovedOfflineBecomesNilAtOnce() async throws {
            let uid = try await FirebaseEmulators.signIn()
            try await seed(.mock, uid: uid)
            let budgets = Recording(await FirestoreStorage.shared.budget(uid: uid))
            defer { budgets.cancel() }
            try await budgets.wait { $0.last == .known(.mock) }

            try await Firestore.firestore().disableNetwork()
            let deletion = Task { try await FirestoreStorage.shared.deleteBudget(uid: uid) }

            try await budgets.wait { $0.last == .known(nil) }
            try await Firestore.firestore().enableNetwork()
            try await deletion.value
        }

        @Test
        func theRulesRefuseAnotherUsersBudget() async throws {
            let owner = try await FirebaseEmulators.signIn()
            try await seed(.mock, uid: owner)
            _ = try await FirebaseEmulators.signIn()

            let error = await #expect(throws: NSError.self) {
                try await FirestoreStorage.shared.saveIncome(1, removingInvestment: false, uid: owner)
            }
            expectNoDifference(error?.code, FirestoreErrorCode.permissionDenied.rawValue)

            let budgets = Recording(await FirestoreStorage.shared.budget(uid: owner))
            defer { budgets.cancel() }
            let failure = try await budgets.waitForFailure() as NSError
            expectNoDifference(failure.code, FirestoreErrorCode.permissionDenied.rawValue)
            expectNoDifference(budgets.values, [])
        }

        @Test
        func eachBudgetWriteKeepsTheOtherField() async throws {
            let uid = try await FirebaseEmulators.signIn()
            let budgets = Recording(await FirestoreStorage.shared.budget(uid: uid))
            defer { budgets.cancel() }
            try await budgets.wait { $0 == [.known(nil)] }

            try await FirestoreStorage.shared.saveIncome(3000, removingInvestment: false, uid: uid)
            try await budgets.wait { $0.last == .known(Budget(income: 3000, investment: nil)) }

            try await FirestoreStorage.shared.saveInvestment(450, uid: uid)
            try await budgets.wait { $0.last == .known(.mock) }

            try await FirestoreStorage.shared.saveIncome(3500, removingInvestment: false, uid: uid)
            try await budgets.wait { $0.last == .known(Budget(income: 3500, investment: 450)) }

            try await FirestoreStorage.shared.removeInvestment(uid: uid)
            try await budgets.wait { $0.last == .known(Budget(income: 3500, investment: nil)) }

            try await FirestoreStorage.shared.saveInvestment(450, uid: uid)
            try await FirestoreStorage.shared.saveIncome(400, removingInvestment: true, uid: uid)
            try await budgets.wait { $0.last == .known(Budget(income: 400, investment: nil)) }
        }

        @Test
        func theRulesRefuseAnInvestmentWithoutAnIncome() async throws {
            let uid = try await FirebaseEmulators.signIn()

            let error = await #expect(throws: NSError.self) {
                try await FirestoreStorage.shared.saveInvestment(450, uid: uid)
            }
            expectNoDifference(error?.code, FirestoreErrorCode.permissionDenied.rawValue)
        }

        @Test
        func theRulesRefuseAnIncomeBelowTheInvestment() async throws {
            let uid = try await FirebaseEmulators.signIn()
            try await seed(.mock, uid: uid)

            let error = await #expect(throws: NSError.self) {
                try await FirestoreStorage.shared.saveIncome(400, removingInvestment: false, uid: uid)
            }
            expectNoDifference(error?.code, FirestoreErrorCode.permissionDenied.rawValue)
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

private func seed(_ budget: Budget, uid: String) async throws {
    try await FirestoreStorage.shared.saveIncome(budget.income, removingInvestment: false, uid: uid)
    if let investment = budget.investment {
        try await FirestoreStorage.shared.saveInvestment(investment, uid: uid)
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
