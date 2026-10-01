//
//  HomeTests.swift
//  OverheadTests
//
//  Created by Lorenzo Mazzarotto on 31/08/26.
//

import ComposableArchitecture
import CustomDump
import Foundation
import Testing

@testable import Overhead

extension BaseSuite {
    @Suite
    @MainActor
    struct HomeTests {
        // The expenses stream and the network monitor start with the session
        @Test
        func theTaskObservesTheExpensesAndTheConnectivity() async {
            let expenses = AsyncThrowingStream<ExpensesSnapshot, any Error>.makeStream()
            let connectivity = AsyncStream<Bool>.makeStream()

            let store = TestStore(initialState: Home.State(user: .mock)) {
                Home()
            } withDependencies: {
                $0.expensesClient.expenses = { uid in
                    expectNoDifference(uid, User.mock.uid)
                    return expenses.stream
                }
                $0.networkMonitorClient.connectivityChanges = { connectivity.stream }
            }

            await store.send(.task)

            expenses.continuation.yield(.mock)
            await store.receive(\.expensesUpdated) {
                $0.$expenses.withLock { $0 = IdentifiedArray(uniqueElements: Expense.mocks) }
                $0.isSyncing = false
            }

            connectivity.continuation.yield(false)
            await store.receive(\.connectivityChanged, false) {
                $0.isOnline = false
            }

            expenses.continuation.finish()
            connectivity.continuation.finish()
            await store.finish()
        }

        // Nil expenses mean the first load, and an empty array means an empty list
        @Test
        func theExpensesAreEmptyWhileTheFirstLoadRuns() {
            let state = Home.State(user: .mock)

            #expect(state.isLoadingFirstExpenses)
            expectNoDifference(state.listedExpenses.map(\.wrappedValue), [])
        }

        // A snapshot stops the syncing only when it comes from the server without a local write
        @Test
        func anExpensesUpdateStoresThemAndStopsTheSyncing() async {
            let store = TestStore(initialState: Home.State(user: .mock)) {
                Home()
            }

            await store.send(.expensesUpdated(.mock)) {
                $0.$expenses.withLock { $0 = IdentifiedArray(uniqueElements: Expense.mocks) }
                $0.isSyncing = false
            }
        }

        @Test
        func theExpenseCountFollowsTheExpenses() {
            let state = Home.State(user: .mock)
            expectNoDifference(state.expenseCount, 0)

            state.$expenses.withLock { $0 = IdentifiedArray(uniqueElements: Expense.mocks) }
            expectNoDifference(state.expenseCount, 3)
        }

        // An empty array replaces nil, so the list shows the empty state and not the spinner
        @Test
        func aFailedFirstLoadShowsTheEmptyStateAndRetries() async {
            let clock = TestClock()
            let hasFailed = LockIsolated(false)

            let store = TestStore(initialState: Home.State(user: .mock)) {
                Home()
            } withDependencies: {
                $0.continuousClock = clock
                $0.expensesClient.expenses = { _ in
                    let isFirstAttempt = hasFailed.withValue { failed -> Bool in
                        defer { failed = true }
                        return !failed
                    }
                    return AsyncThrowingStream { continuation in
                        isFirstAttempt
                            ? continuation.finish(throwing: ExpensesFailure())
                            : continuation.finish()
                    }
                }
                $0.networkMonitorClient.connectivityChanges = {
                    AsyncStream { continuation in continuation.finish() }
                }
            }

            await store.send(.task)
            await store.receive(\.expensesStreamFailed) {
                $0.$expenses.withLock { $0 = [] }
            }

            await clock.advance(by: .seconds(5))
            await store.receive(\.expensesRetryTimerElapsed)
            await store.finish()
        }

        // The expenses the user can already read must not disappear on a failure
        @Test
        func aFailedStreamKeepsTheExpensesAndRetriesAfterFiveSeconds() async {
            let clock = TestClock()
            var state = Home.State(user: .mock)
            state.$expenses.withLock { $0 = IdentifiedArray(uniqueElements: Expense.mocks) }
            state.isSyncing = false

            let store = TestStore(initialState: state) {
                Home()
            } withDependencies: {
                $0.continuousClock = clock
                $0.expensesClient.expenses = { _ in
                    AsyncThrowingStream { continuation in continuation.finish() }
                }
            }

            await store.send(.expensesStreamFailed) {
                $0.isSyncing = true
            }
            await clock.advance(by: .seconds(4))
            await store.send(.connectivityChanged(false)) {
                $0.isOnline = false
            }
            await clock.advance(by: .seconds(1))
            await store.receive(\.expensesRetryTimerElapsed)
            await store.finish()
        }

        // Only the first load welcomes the user, and the later ones stay quiet
        @Test
        func aFreshSignInPlaysItsHapticOnlyOnTheFirstLoad() async {
            let state = Home.State(user: .mock, sessionOrigin: .freshSignIn(isNewAccount: false))

            await confirmation("Plays the success haptic") { playsHaptic in
                let store = TestStore(initialState: state) {
                    Home()
                } withDependencies: {
                    $0.hapticsClient.success = { playsHaptic() }
                }

                await store.send(.expensesUpdated(.mock)) {
                    $0.$expenses.withLock { $0 = IdentifiedArray(uniqueElements: Expense.mocks) }
                    $0.isSyncing = false
                }
                await store.send(.expensesUpdated(.mock))
                await store.finish()
            }
        }

        // The haptic welcomes the user, so it does not depend on the expenses
        @Test
        func aFreshSignInPlaysItsHapticEvenWhenTheFirstLoadFails() async {
            let clock = TestClock()
            let state = Home.State(user: .mock, sessionOrigin: .freshSignIn(isNewAccount: false))

            await confirmation("Plays the success haptic") { playsHaptic in
                let store = TestStore(initialState: state) {
                    Home()
                } withDependencies: {
                    $0.continuousClock = clock
                    $0.expensesClient.expenses = { _ in
                        AsyncThrowingStream { continuation in continuation.finish() }
                    }
                    $0.hapticsClient.success = { playsHaptic() }
                }

                await store.send(.expensesStreamFailed) {
                    $0.$expenses.withLock { $0 = [] }
                }
                await clock.advance(by: .seconds(5))
                await store.receive(\.expensesRetryTimerElapsed)
                await store.finish()
            }
        }

        // A sync cannot finish without a network, so the offline status wins
        @Test
        func theConnectivityDrivesTheSyncStatus() async {
            var state = Home.State(user: .mock)
            state.$expenses.withLock { $0 = IdentifiedArray(uniqueElements: Expense.mocks) }
            state.isSyncing = false

            let store = TestStore(initialState: state) {
                Home()
            }

            expectNoDifference(store.state.syncStatus, .synced)

            await store.send(.connectivityChanged(false)) {
                $0.isOnline = false
            }
            expectNoDifference(store.state.syncStatus, .offline)

            await store.send(.expensesUpdated(.syncing)) {
                $0.isSyncing = true
            }
            expectNoDifference(store.state.syncStatus, .offline)

            await store.send(.connectivityChanged(true)) {
                $0.isOnline = true
            }
            expectNoDifference(store.state.syncStatus, .syncing)
        }

        @Test
        func theEmptyStateFollowsTheExpenses() {
            let state = Home.State(user: .mock)
            #expect(!state.isEmpty)

            state.$expenses.withLock { $0 = [] }
            #expect(state.isEmpty)

            state.$expenses.withLock { $0 = IdentifiedArray(uniqueElements: Expense.mocks) }
            #expect(!state.isEmpty)
        }

        // A form without an expense creates one, and a form with an expense edits it
        @Test
        func theNewExpenseButtonOpensAnEmptyForm() async {
            let store = TestStore(initialState: Home.State(user: .mock)) {
                Home()
            }

            await store.send(.newExpenseButtonTapped) {
                $0.destination = .createExpense(ExpenseForm.State())
            }
        }

        // The form only reports the expense, and home writes it to the server
        @Test
        func creatingAnExpenseSavesItAndClosesTheForm() async {
            let now = Date(timeIntervalSince1970: 1_751_000_000)
            let created = Expense(
                createdAt: now,
                definition: "The easiest wins, taken first.",
                id: UUID(0),
                term: "Low-hanging fruit"
            )

            var state = Home.State(user: .mock)
            state.$expenses.withLock { $0 = IdentifiedArray(uniqueElements: Expense.mocks) }
            state.destination = .createExpense(ExpenseForm.State())

            await confirmation("Saves the expense") { savesExpense in
                await confirmation("Plays the success haptic") { playsHaptic in
                    let store = TestStore(initialState: state) {
                        Home()
                    } withDependencies: {
                        $0.date.now = now
                        $0.expensesClient.save = { expense, uid in
                            expectNoDifference(expense, created)
                            expectNoDifference(uid, User.mock.uid)
                            savesExpense()
                        }
                        $0.hapticsClient.success = { playsHaptic() }
                        $0.uuid = .incrementing
                    }

                    store.exhaustivity = .off

                    await store.send(
                        .destination(.presented(.createExpense(.binding(.set(\.term, "  Low-hanging fruit  ")))))
                    )
                    await store.send(
                        .destination(.presented(.createExpense(.binding(.set(\.definition, created.definition)))))
                    )
                    await store.send(.destination(.presented(.createExpense(.saveButtonTapped))))
                    await store.receive(\.destination.presented.createExpense.delegate.didSubmit) {
                        $0.destination = nil
                    }
                    await store.finish()
                }
            }
        }

        // Home reads the delegate actions only, and the detail keeps the rest
        @Test
        func aNonDelegateDetailActionIsHandledByTheDetail() async {
            var state = Home.State(user: .mock)
            state.$expenses.withLock { $0 = IdentifiedArray(uniqueElements: Expense.mocks) }
            state.path.append(ExpenseDetail.State(expense: SharedReader(value: .blueMoon)))
            let detailID = Array(state.path.ids)[0]

            let store = TestStore(initialState: state) {
                Home()
            }

            await store.send(.path(.element(id: detailID, action: .deleteButtonTapped))) {
                $0.path[id: detailID]?.destination = .alert(.confirmDeletion)
            }
        }

        // The detail stays on screen because it reads the expense from the shared state
        @Test
        func updatingFromTheDetailSavesTheExpense() async {
            var updated = Expense.burningCandle
            updated.term = "Burn the midnight oil"

            var state = Home.State(user: .mock)
            state.$expenses.withLock { $0 = IdentifiedArray(uniqueElements: Expense.mocks) }
            state.path.append(ExpenseDetail.State(expense: SharedReader(value: .burningCandle)))
            let detailID = Array(state.path.ids)[0]

            await confirmation("Saves the expense") { savesExpense in
                let store = TestStore(initialState: state) {
                    Home()
                } withDependencies: {
                    $0.expensesClient.save = { [updated] expense, uid in
                        expectNoDifference(expense, updated)
                        expectNoDifference(uid, User.mock.uid)
                        savesExpense()
                    }
                }

                await store.send(
                    .path(.element(id: detailID, action: .delegate(.didUpdate(updated))))
                )
                await store.finish()
            }
        }

        // The save leaves no trace on screen, so an alert must report the failure
        @Test
        func aFailedSaveNotifiesTheSession() async {
            var state = Home.State(user: .mock)
            state.$expenses.withLock { $0 = IdentifiedArray(uniqueElements: Expense.mocks) }
            state.path.append(ExpenseDetail.State(expense: SharedReader(value: .blueMoon)))
            let detailID = Array(state.path.ids)[0]

            let store = TestStore(initialState: state) {
                Home()
            } withDependencies: {
                $0.expensesClient.save = { _, _ in throw ExpensesFailure() }
            }

            await store.send(
                .path(.element(id: detailID, action: .delegate(.didUpdate(.blueMoon))))
            )
            await store.receive(\.delegate.didFailToSave)
        }

        // The detail leaves the stack first because its expense is about to disappear
        @Test
        func deletingFromTheDetailPopsBackAndDeletesTheExpense() async {
            var state = Home.State(user: .mock)
            state.$expenses.withLock { $0 = IdentifiedArray(uniqueElements: Expense.mocks) }
            state.path.append(ExpenseDetail.State(expense: SharedReader(value: .blueMoon)))
            let detailID = Array(state.path.ids)[0]

            await confirmation("Deletes the expense") { deletesExpense in
                let store = TestStore(initialState: state) {
                    Home()
                } withDependencies: {
                    $0.expensesClient.delete = { id, uid in
                        expectNoDifference(id, Expense.blueMoon.id)
                        expectNoDifference(uid, User.mock.uid)
                        deletesExpense()
                    }
                    $0.hapticsClient.warning = {}
                }

                await store.send(
                    .path(.element(id: detailID, action: .delegate(.didDelete(Expense.blueMoon.id))))
                ) {
                    $0.path.pop(from: detailID)
                }
                await store.finish()
            }
        }

        // The detail pops before the delete reaches the server, so an alert must report the failure
        @Test
        func aFailedDeletionNotifiesTheSession() async {
            var state = Home.State(user: .mock)
            state.$expenses.withLock { $0 = IdentifiedArray(uniqueElements: Expense.mocks) }
            state.path.append(ExpenseDetail.State(expense: SharedReader(value: .blueMoon)))
            let detailID = Array(state.path.ids)[0]

            let store = TestStore(initialState: state) {
                Home()
            } withDependencies: {
                $0.expensesClient.delete = { _, _ in throw ExpensesFailure() }
                $0.hapticsClient.warning = {}
            }

            await store.send(
                .path(.element(id: detailID, action: .delegate(.didDelete(Expense.blueMoon.id))))
            ) {
                $0.path.pop(from: detailID)
            }
            await store.receive(\.delegate.didFailToDelete)
        }

        // A different device can delete the expense while its detail is on screen
        @Test
        func aDeletedExpensePopsItsDetail() async {
            let remaining = [Expense.burningCandle, Expense.lowHangingFruit]
            var state = Home.State(user: .mock)
            state.$expenses.withLock { $0 = IdentifiedArray(uniqueElements: Expense.mocks) }
            state.path.append(ExpenseDetail.State(expense: SharedReader(value: .blueMoon)))
            let detailID = Array(state.path.ids)[0]

            let store = TestStore(initialState: state) {
                Home()
            }

            await store.send(.expensesUpdated(ExpensesSnapshot(expenses: remaining, isSyncing: false))) {
                $0.$expenses.withLock { $0 = IdentifiedArray(uniqueElements: remaining) }
                $0.isSyncing = false
                $0.path.pop(from: detailID)
            }
        }

        // A snapshot that still holds the expense must not disturb the stack
        @Test
        func aSurvivingExpenseKeepsItsDetail() async {
            var state = Home.State(user: .mock)
            state.$expenses.withLock { $0 = IdentifiedArray(uniqueElements: Expense.mocks) }
            state.path.append(ExpenseDetail.State(expense: SharedReader(value: .blueMoon)))
            state.isSyncing = false

            let store = TestStore(initialState: state) {
                Home()
            }

            await store.send(.expensesUpdated(.mock))
        }

        private struct ExpensesFailure: Error {}
    }
}
