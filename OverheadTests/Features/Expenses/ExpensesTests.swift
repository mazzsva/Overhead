//
//  ExpensesTests.swift
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
    struct ExpensesTests {
        // The expenses stream starts with the session
        @Test
        func theTaskObservesTheExpenses() async {
            let expenses = AsyncThrowingStream<[Expense], any Error>.makeStream()

            let store = TestStore(initialState: Expenses.State(user: .mock)) {
                Expenses()
            } withDependencies: {
                $0.expensesClient.expenses = { uid in
                    expectNoDifference(uid, User.mock.uid)
                    return expenses.stream
                }
            }

            await store.send(.task)

            expenses.continuation.yield(Expense.mocks)
            await store.receive(\.expensesUpdated) {
                $0.$expenses.withLock { $0 = IdentifiedArray(uniqueElements: Expense.mocks) }
            }

            expenses.continuation.finish()
            await store.finish()
        }

        // Nil expenses mean the first load, and an empty array means an empty list
        @Test
        func theExpensesAreEmptyWhileTheFirstLoadRuns() {
            let state = Expenses.State(user: .mock)

            #expect(state.isLoadingFirstExpenses)
            expectNoDifference(state.listedExpenses.map(\.wrappedValue), [])
        }

        // An empty array replaces nil, so the list shows the empty state and not the spinner
        @Test
        func aFailedFirstLoadShowsTheEmptyStateAndRetries() async {
            let clock = TestClock()
            let hasFailed = LockIsolated(false)

            let store = TestStore(initialState: Expenses.State(user: .mock)) {
                Expenses()
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
            var state = Expenses.State(user: .mock)
            state.$expenses.withLock { $0 = IdentifiedArray(uniqueElements: Expense.mocks) }

            let store = TestStore(initialState: state) {
                Expenses()
            } withDependencies: {
                $0.continuousClock = clock
                $0.expensesClient.expenses = { _ in
                    AsyncThrowingStream { continuation in continuation.finish() }
                }
            }

            await store.send(.expensesStreamFailed)
            await clock.advance(by: .seconds(5))
            await store.receive(\.expensesRetryTimerElapsed)
            await store.finish()
        }

        // Only the first load welcomes the user, and the later ones stay quiet
        @Test
        func aFreshSignInPlaysItsHapticOnlyOnTheFirstLoad() async {
            let state = Expenses.State(user: .mock, sessionOrigin: .freshSignIn(isNewAccount: false))

            await confirmation("Plays the success haptic") { playsHaptic in
                let store = TestStore(initialState: state) {
                    Expenses()
                } withDependencies: {
                    $0.hapticsClient.success = { playsHaptic() }
                }

                await store.send(.expensesUpdated(Expense.mocks)) {
                    $0.$expenses.withLock { $0 = IdentifiedArray(uniqueElements: Expense.mocks) }
                }
                await store.send(.expensesUpdated(Expense.mocks))
                await store.finish()
            }
        }

        // The haptic welcomes the user, so it does not depend on the expenses
        @Test
        func aFreshSignInPlaysItsHapticEvenWhenTheFirstLoadFails() async {
            let clock = TestClock()
            let state = Expenses.State(user: .mock, sessionOrigin: .freshSignIn(isNewAccount: false))

            await confirmation("Plays the success haptic") { playsHaptic in
                let store = TestStore(initialState: state) {
                    Expenses()
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

        @Test
        func theEmptyStateFollowsTheExpenses() {
            let state = Expenses.State(user: .mock)
            #expect(!state.isEmpty)

            state.$expenses.withLock { $0 = [] }
            #expect(state.isEmpty)

            state.$expenses.withLock { $0 = IdentifiedArray(uniqueElements: Expense.mocks) }
            #expect(!state.isEmpty)
        }

        // A form without an expense creates one, and a form with an expense edits it
        @Test
        func theNewExpenseButtonOpensAnEmptyForm() async {
            let store = TestStore(initialState: Expenses.State(user: .mock)) {
                Expenses()
            }

            await store.send(.newExpenseButtonTapped) {
                $0.destination = .createExpense(ExpenseForm.State())
            }
        }

        @Test
        func theNewExpenseFormStartsInTheDefaultCurrency() async {
            @Shared(.defaultCurrencyCode(uid: User.mock.uid)) var defaultCurrencyCode
            $defaultCurrencyCode.withLock { $0 = "BRL" }

            let store = TestStore(initialState: Expenses.State(user: .mock)) {
                Expenses()
            }

            await store.send(.newExpenseButtonTapped) {
                $0.destination = .createExpense(ExpenseForm.State(defaultCurrencyCode: "BRL"))
            }
        }

        // The form only reports the expense, and Expenses writes it to the server
        @Test
        func creatingAnExpenseSavesItAndClosesTheForm() async {
            let now = Date(timeIntervalSince1970: 1_751_000_000)
            let created = Expense(
                amount: Decimal(minorUnits: 1299, currencyCode: "USD"),
                billingCycle: .monthly,
                createdAt: now,
                currencyCode: "USD",
                id: UUID(0),
                isActive: true,
                name: "Phone Plan"
            )

            var state = Expenses.State(user: .mock)
            state.$expenses.withLock { $0 = IdentifiedArray(uniqueElements: Expense.mocks) }
            state.destination = .createExpense(ExpenseForm.State())

            await confirmation("Saves the expense") { savesExpense in
                await confirmation("Plays the success haptic") { playsHaptic in
                    let store = TestStore(initialState: state) {
                        Expenses()
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
                        .destination(.presented(.createExpense(.binding(.set(\.name, "  Phone Plan  ")))))
                    )
                    await store.send(
                        .destination(.presented(.createExpense(.binding(.set(\.amountText, "12.99")))))
                    )
                    await store.send(.destination(.presented(.createExpense(.saveButtonTapped))))
                    await store.receive(\.destination.presented.createExpense.delegate.didSubmit) {
                        $0.destination = nil
                    }
                    await store.finish()
                }
            }
        }

        // Expenses reads the delegate actions only, and the detail keeps the rest
        @Test
        func aNonDelegateDetailActionIsHandledByTheDetail() async {
            var state = Expenses.State(user: .mock)
            state.$expenses.withLock { $0 = IdentifiedArray(uniqueElements: Expense.mocks) }
            state.path.append(ExpenseDetail.State(expense: SharedReader(value: .rent)))
            let detailID = Array(state.path.ids)[0]

            let store = TestStore(initialState: state) {
                Expenses()
            }

            await store.send(.path(.element(id: detailID, action: .deleteButtonTapped))) {
                $0.path[id: detailID]?.destination = .alert(.confirmDeletion)
            }
        }

        // The detail stays on screen because it reads the expense from the shared state
        @Test
        func updatingFromTheDetailSavesTheExpense() async {
            var updated = Expense.gym
            updated.amount = 45

            var state = Expenses.State(user: .mock)
            state.$expenses.withLock { $0 = IdentifiedArray(uniqueElements: Expense.mocks) }
            state.path.append(ExpenseDetail.State(expense: SharedReader(value: .gym)))
            let detailID = Array(state.path.ids)[0]

            await confirmation("Saves the expense") { savesExpense in
                let store = TestStore(initialState: state) {
                    Expenses()
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
            var state = Expenses.State(user: .mock)
            state.$expenses.withLock { $0 = IdentifiedArray(uniqueElements: Expense.mocks) }
            state.path.append(ExpenseDetail.State(expense: SharedReader(value: .rent)))
            let detailID = Array(state.path.ids)[0]

            let store = TestStore(initialState: state) {
                Expenses()
            } withDependencies: {
                $0.expensesClient.save = { _, _ in throw ExpensesFailure() }
            }

            await store.send(
                .path(.element(id: detailID, action: .delegate(.didUpdate(.rent))))
            )
            await store.receive(\.delegate.didFailToSave)
        }

        // The detail leaves the stack first because its expense is about to disappear
        @Test
        func deletingFromTheDetailPopsBackAndDeletesTheExpense() async {
            var state = Expenses.State(user: .mock)
            state.$expenses.withLock { $0 = IdentifiedArray(uniqueElements: Expense.mocks) }
            state.path.append(ExpenseDetail.State(expense: SharedReader(value: .rent)))
            let detailID = Array(state.path.ids)[0]

            await confirmation("Deletes the expense") { deletesExpense in
                let store = TestStore(initialState: state) {
                    Expenses()
                } withDependencies: {
                    $0.expensesClient.delete = { id, uid in
                        expectNoDifference(id, Expense.rent.id)
                        expectNoDifference(uid, User.mock.uid)
                        deletesExpense()
                    }
                    $0.hapticsClient.warning = {}
                }

                await store.send(
                    .path(.element(id: detailID, action: .delegate(.didDelete(Expense.rent.id))))
                ) {
                    $0.path.pop(from: detailID)
                }
                await store.finish()
            }
        }

        // The detail pops before the delete reaches the server, so an alert must report the failure
        @Test
        func aFailedDeletionNotifiesTheSession() async {
            var state = Expenses.State(user: .mock)
            state.$expenses.withLock { $0 = IdentifiedArray(uniqueElements: Expense.mocks) }
            state.path.append(ExpenseDetail.State(expense: SharedReader(value: .rent)))
            let detailID = Array(state.path.ids)[0]

            let store = TestStore(initialState: state) {
                Expenses()
            } withDependencies: {
                $0.expensesClient.delete = { _, _ in throw ExpensesFailure() }
                $0.hapticsClient.warning = {}
            }

            await store.send(
                .path(.element(id: detailID, action: .delegate(.didDelete(Expense.rent.id))))
            ) {
                $0.path.pop(from: detailID)
            }
            await store.receive(\.delegate.didFailToDelete)
        }

        // A different device can delete the expense while its detail is on screen
        @Test
        func aDeletedExpensePopsItsDetail() async {
            let remaining = [Expense.gym, Expense.phonePlan]
            var state = Expenses.State(user: .mock)
            state.$expenses.withLock { $0 = IdentifiedArray(uniqueElements: Expense.mocks) }
            state.path.append(ExpenseDetail.State(expense: SharedReader(value: .rent)))
            let detailID = Array(state.path.ids)[0]

            let store = TestStore(initialState: state) {
                Expenses()
            }

            await store.send(.expensesUpdated(remaining)) {
                $0.$expenses.withLock { $0 = IdentifiedArray(uniqueElements: remaining) }
                $0.path.pop(from: detailID)
            }
        }

        // A snapshot that still holds the expense must not disturb the stack
        @Test
        func aSurvivingExpenseKeepsItsDetail() async {
            var state = Expenses.State(user: .mock)
            state.$expenses.withLock { $0 = IdentifiedArray(uniqueElements: Expense.mocks) }
            state.path.append(ExpenseDetail.State(expense: SharedReader(value: .rent)))

            let store = TestStore(initialState: state) {
                Expenses()
            }

            await store.send(.expensesUpdated(Expense.mocks))
        }

        private struct ExpensesFailure: Error {}
    }
}
