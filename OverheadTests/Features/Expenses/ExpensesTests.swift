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
        @Test
        func expensesAreSortedFromTheHighestMonthlyAmount() async {
            var gym = Expense.gym
            gym.amount = 65
            var yearly = Expense.rent
            yearly.billingCycle = .yearly
            yearly.amount = 1200
            var inactive = Expense.phonePlan
            inactive.amount = 5000
            let sameAmount = Expense(
                amount: 100,
                billingCycle: .monthly,
                createdAt: .distantPast,
                id: UUID(3),
                isActive: true,
                name: "Cloud Storage"
            )

            let store = TestStore(initialState: Expenses.State(user: .mock)) {
                Expenses()
            }

            await store.send(.expensesUpdated([inactive, yearly, gym, sameAmount])) {
                $0.$expenses.withLock {
                    $0 = IdentifiedArray(uniqueElements: [inactive, sameAmount, yearly, gym])
                }
            }
            expectNoDifference(store.state.activeExpenses, [sameAmount, yearly, gym])
            expectNoDifference(store.state.inactiveExpenses, [inactive])
        }

        // The expenses stream starts with the session
        @Test
        func equalExpensesAreSortedByDateAndThenByIdentity() {
            let older = Expense(
                amount: 10,
                billingCycle: .monthly,
                createdAt: Date(timeIntervalSince1970: 0),
                id: UUID(1),
                isActive: true,
                name: "Gym"
            )
            let twin = Expense(
                amount: 10,
                billingCycle: .monthly,
                createdAt: Date(timeIntervalSince1970: 0),
                id: UUID(0),
                isActive: true,
                name: "Gym"
            )
            let newer = Expense(
                amount: 10,
                billingCycle: .monthly,
                createdAt: Date(timeIntervalSince1970: 100),
                id: UUID(2),
                isActive: true,
                name: "Gym"
            )

            expectNoDifference([older, twin, newer].sorted(by: Expense.listOrder), [newer, twin, older])
        }

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
            expectNoDifference(state.activeExpenses, [])
            expectNoDifference(state.inactiveExpenses, [])
        }

        @Test
        func theSectionsFollowTheStatusOfTheExpenses() async {
            let store = TestStore(initialState: Expenses.State(user: .mock)) {
                Expenses()
            }

            await store.send(.expensesUpdated(Expense.mocks)) {
                $0.$expenses.withLock { $0 = IdentifiedArray(uniqueElements: Expense.mocks) }
            }
            expectNoDifference(store.state.activeExpenses, [.rent, .gym])
            expectNoDifference(store.state.inactiveExpenses, [.phonePlan])

            var pausedRent = Expense.rent
            pausedRent.isActive = false
            await store.send(.expensesUpdated([pausedRent, .gym, .phonePlan])) {
                $0.$expenses.withLock { $0 = IdentifiedArray(uniqueElements: [pausedRent, .gym, .phonePlan]) }
            }
            expectNoDifference(store.state.activeExpenses, [.gym])
            expectNoDifference(store.state.inactiveExpenses, [pausedRent, .phonePlan])
        }

        @Test
        func theInactiveSectionIsEmptyWithoutInactiveExpenses() async {
            let store = TestStore(initialState: Expenses.State(user: .mock)) {
                Expenses()
            }

            await store.send(.expensesUpdated([.rent, .gym])) {
                $0.$expenses.withLock { $0 = [.rent, .gym] }
            }
            expectNoDifference(store.state.activeExpenses, [.rent, .gym])
            expectNoDifference(store.state.inactiveExpenses, [])

            await store.send(.expensesUpdated([])) {
                $0.$expenses.withLock { $0 = [] }
            }
            expectNoDifference(store.state.activeExpenses, [])
            expectNoDifference(store.state.inactiveExpenses, [])
        }

        @Test
        func theActiveSectionIsEmptyWhenEveryExpenseIsInactive() async {
            var pausedRent = Expense.rent
            pausedRent.isActive = false
            var pausedGym = Expense.gym
            pausedGym.isActive = false

            let store = TestStore(initialState: Expenses.State(user: .mock)) {
                Expenses()
            }

            await store.send(.expensesUpdated([pausedGym, pausedRent])) {
                $0.$expenses.withLock { $0 = [pausedRent, pausedGym] }
            }
            expectNoDifference(store.state.activeExpenses, [])
            expectNoDifference(store.state.inactiveExpenses, [pausedRent, pausedGym])
        }

        @Test
        func tappingAnExpenseOpensItsDetail() async {
            let state = Expenses.State(user: .mock)
            state.$expenses.withLock { $0 = IdentifiedArray(uniqueElements: Expense.mocks) }

            let store = TestStore(initialState: state) {
                Expenses()
            }

            await store.send(.expenseCardTapped(Expense.gym.id)) {
                $0.path[id: 0] = ExpenseDetail.State(expense: SharedReader(value: .gym))
            }

            var edited = Expense.gym
            edited.isActive = false
            await store.send(.expensesUpdated([.rent, edited, .phonePlan])) {
                $0.$expenses.withLock { $0 = IdentifiedArray(uniqueElements: [.rent, edited, .phonePlan]) }
            }
            expectNoDifference(store.state.path[id: 0]?.expense, edited)
        }

        @Test
        func aSecondTapDoesNotOpenASecondDetail() async {
            let state = Expenses.State(user: .mock)
            state.$expenses.withLock { $0 = IdentifiedArray(uniqueElements: Expense.mocks) }

            let store = TestStore(initialState: state) {
                Expenses()
            }

            await store.send(.expenseCardTapped(Expense.gym.id)) {
                $0.path[id: 0] = ExpenseDetail.State(expense: SharedReader(value: .gym))
            }
            await store.send(.expenseCardTapped(Expense.rent.id))
            await store.send(.expenseCardTapped(Expense.gym.id))
        }

        @Test
        func removingATappedExpenseClosesItsDetail() async {
            let state = Expenses.State(user: .mock)
            state.$expenses.withLock { $0 = IdentifiedArray(uniqueElements: Expense.mocks) }

            let store = TestStore(initialState: state) {
                Expenses()
            }

            await store.send(.expenseCardTapped(Expense.gym.id)) {
                $0.path[id: 0] = ExpenseDetail.State(expense: SharedReader(value: .gym))
            }
            await store.send(.expensesUpdated([.rent, .phonePlan])) {
                $0.$expenses.withLock { $0 = [.rent, .phonePlan] }
                $0.path.pop(from: 0)
            }
        }

        @Test
        func tappingARemovedExpenseDoesNothing() async {
            let state = Expenses.State(user: .mock)
            state.$expenses.withLock { $0 = [.rent, .phonePlan] }

            let store = TestStore(initialState: state) {
                Expenses()
            }

            await store.send(.expenseCardTapped(Expense.gym.id))
        }

        @Test
        func tappingAMissingExpenseDoesNothing() async {
            let store = TestStore(initialState: Expenses.State(user: .mock)) {
                Expenses()
            }

            await store.send(.expenseCardTapped(Expense.gym.id))
        }

        // The failure ends the loading window, so the list shows the failure and not the spinner
        @Test
        func aFailedFirstLoadShowsTheFailureAndRetriesAfterFiveSeconds() async {
            let clock = TestClock()
            let attempts = LockIsolated(0)

            let store = TestStore(initialState: Expenses.State(user: .mock)) {
                Expenses()
            } withDependencies: {
                $0.continuousClock = clock
                $0.expensesClient.expenses = { _ in
                    let attempt = attempts.withValue {
                        $0 += 1
                        return $0
                    }
                    return AsyncThrowingStream { continuation in
                        if attempt == 1 {
                            continuation.finish(throwing: ExpensesFailure())
                        } else {
                            continuation.yield(Expense.mocks)
                            continuation.finish()
                        }
                    }
                }
            }

            await store.send(.task)
            await store.receive(\.expensesStreamFailed) {
                $0.hasFailedFirstLoad = true
            }
            #expect(!store.state.isLoadingFirstExpenses)

            await clock.advance(by: .seconds(4))
            expectNoDifference(attempts.value, 1)

            await clock.advance(by: .seconds(1))
            await store.receive(\.expensesUpdated) {
                $0.$expenses.withLock { $0 = IdentifiedArray(uniqueElements: Expense.mocks) }
                $0.hasFailedFirstLoad = false
            }
            await store.finish()
            expectNoDifference(attempts.value, 2)
        }

        // The expenses the user can already read must not disappear on a failure
        @Test
        func aFailedStreamKeepsTheExpensesAndRetriesAfterFiveSeconds() async {
            let clock = TestClock()
            let attempts = LockIsolated(0)
            let state = Expenses.State(user: .mock)
            state.$expenses.withLock { $0 = IdentifiedArray(uniqueElements: Expense.mocks) }

            let store = TestStore(initialState: state) {
                Expenses()
            } withDependencies: {
                $0.continuousClock = clock
                $0.expensesClient.expenses = { _ in
                    let attempt = attempts.withValue {
                        $0 += 1
                        return $0
                    }
                    return AsyncThrowingStream { continuation in
                        attempt == 1 ? continuation.finish(throwing: ExpensesFailure()) : continuation.finish()
                    }
                }
            }

            await store.send(.task)
            await store.receive(\.expensesStreamFailed)
            await clock.advance(by: .seconds(5))
            await store.finish()
            expectNoDifference(attempts.value, 2)
        }

        // Only the first load welcomes the user, and the later ones stay quiet
        @Test
        func aFreshSignInPlaysItsHapticOnlyOnTheFirstLoad() async {
            let state = Expenses.State(user: .mock, sessionOrigin: .freshSignIn)

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
            let state = Expenses.State(user: .mock, sessionOrigin: .freshSignIn)

            await confirmation("Plays the success haptic") { playsHaptic in
                let store = TestStore(initialState: state) {
                    Expenses()
                } withDependencies: {
                    $0.hapticsClient.success = { playsHaptic() }
                }

                await store.send(.expensesStreamFailed) {
                    $0.hasFailedFirstLoad = true
                }
                await store.send(.expensesStreamFailed)
                await store.send(.expensesUpdated(Expense.mocks)) {
                    $0.$expenses.withLock { $0 = IdentifiedArray(uniqueElements: Expense.mocks) }
                    $0.hasFailedFirstLoad = false
                }
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

        // The form only reports the expense, and Expenses writes it to the server
        @Test
        func creatingAnExpenseSavesItAndClosesTheForm() async {
            let now = Date(timeIntervalSince1970: 1_751_000_000)
            let created = Expense(
                amount: 13,
                billingCycle: .monthly,
                createdAt: now,
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

                    await store.send(
                        .destination(.presented(.createExpense(.binding(.set(\.name, "  Phone Plan  ")))))
                    ) {
                        $0.destination?.modify(\.createExpense) { $0.name = "  Phone Plan  " }
                    }
                    await store.send(
                        .destination(.presented(.createExpense(.binding(.set(\.amountText, "13")))))
                    ) {
                        $0.destination?.modify(\.createExpense) { $0.amountText = "13" }
                    }
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
