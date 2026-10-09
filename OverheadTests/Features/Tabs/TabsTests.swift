//
//  TabsTests.swift
//  OverheadTests
//
//  Created by Lorenzo Mazzarotto on 01/10/26.
//

import ComposableArchitecture
import CustomDump
import Foundation
import Testing

@testable import Overhead

extension BaseSuite {
    @Suite
    @MainActor
    struct TabsTests {
        @Test
        func theOverviewFollowsTheExpenses() async {
            let store = TestStore(initialState: Tabs.State(user: .mock)) {
                Tabs()
            }
            expectNoDifference(store.state.overview.monthlyTotal, nil)

            await store.send(.expenses(.expensesUpdated(Expense.mocks))) {
                $0.expenses.$expenses.withLock { $0 = IdentifiedArray(uniqueElements: Expense.mocks) }
            }
            expectNoDifference(store.state.overview.monthlyTotal, Decimal(cents: 98_990))

            var pausedRent = Expense.rent
            pausedRent.isActive = false
            await store.send(.expenses(.expensesUpdated([pausedRent, .gym, .phonePlan]))) {
                $0.expenses.$expenses.withLock {
                    $0 = IdentifiedArray(uniqueElements: [pausedRent, .gym, .phonePlan])
                }
            }
            expectNoDifference(store.state.overview.monthlyTotal, Decimal(cents: 3990))
        }

        @Test
        func theOverviewTaskObservesTheBudget() async {
            let budget = AsyncThrowingStream<BudgetSnapshot, any Error>.makeStream()

            let store = TestStore(initialState: Tabs.State(user: .mock)) {
                Tabs()
            } withDependencies: {
                $0.budgetClient.budget = { uid in
                    expectNoDifference(uid, User.mock.uid)
                    return budget.stream
                }
            }

            await store.send(.overview(.task))
            budget.continuation.yield(BudgetSnapshot(budget: .mock, isFromCache: false))
            await store.receive(\.overview.budgetUpdated) {
                $0.overview.budgetStatus = .loaded(.mock)
            }
            budget.continuation.finish()
            await store.finish()
        }

        @Test
        func theOverviewExpensesRowSelectsTheExpensesTab() async {
            let store = TestStore(initialState: Tabs.State(user: .mock)) {
                Tabs()
            }

            await store.send(.overview(.expensesRowTapped))
            await store.receive(\.overview.delegate.didSelectExpenses) {
                $0.selectedTab = .expenses
            }
        }

        @Test(arguments: [
            (Overview.BudgetChange.removeIncome, "Your income couldn't be removed."),
            (.removeInvestments, "Your savings couldn't be removed."),
            (.saveIncome, "Your income couldn't be saved."),
            (.saveInvestments, "Your savings couldn't be updated."),
        ])
        func aFailedBudgetChangeShowsAnAlert(change: Overview.BudgetChange, message: String) async {
            let state = makeReadyState()

            let store = TestStore(initialState: state) {
                Tabs()
            }

            await store.send(.overview(.delegate(.didFailToChangeBudget(change)))) {
                $0.failedOperations = [.budget(change)]
            }
            #expect(store.state.isPresentingFailure)
            expectNoDifference(store.state.failureMessage, message)
        }

        @Test
        func aFailureWaitsForTheBudgetForms() {
            var state = makeReadyState()
            state.failedOperations = [.saveExpense]
            state.overview.destination = .incomeForm(IncomeForm.State(budget: nil))
            #expect(!state.isPresentingFailure)

            state.overview.destination = .investmentForm(InvestmentForm.State(income: 3000, investment: nil))
            #expect(!state.isPresentingFailure)

            state.overview.destination = nil
            #expect(state.isPresentingFailure)
        }

        @Test
        func aFailedSaveShowsAnAlert() async {
            let state = makeReadyState()

            let store = TestStore(initialState: state) {
                Tabs()
            }

            await store.send(.expenses(.delegate(.didFailToSave))) {
                $0.failedOperations = [.saveExpense]
            }
            #expect(store.state.isPresentingFailure)
            expectNoDifference(store.state.failureMessage, "Your expense couldn't be saved.")
        }

        @Test
        func differentFailuresShowACombinedMessage() async {
            let state = makeReadyState()

            let store = TestStore(initialState: state) {
                Tabs()
            }

            await store.send(.expenses(.delegate(.didFailToSave))) {
                $0.failedOperations = [.saveExpense]
            }
            await store.send(.expenses(.delegate(.didFailToSave)))
            await store.send(.expenses(.delegate(.didFailToDelete))) {
                $0.failedOperations = [.deleteExpense, .saveExpense]
            }
            expectNoDifference(
                store.state.failureMessage,
                "Some of your changes couldn't be saved."
            )
        }

        @Test
        func dismissingTheAlertClearsTheFailures() async {
            var state = makeReadyState()
            state.failedOperations = [.deleteExpense, .saveExpense]

            let store = TestStore(initialState: state) {
                Tabs()
            }

            await store.send(.failurePresentationChanged(false)) {
                $0.failedOperations = []
            }
        }

        @Test
        func aHiddenAlertKeepsTheFailures() async {
            var state = makeReadyState()
            state.failedOperations = [.saveExpense]
            state.settings.alert = .signOutFailed

            let store = TestStore(initialState: state) {
                Tabs()
            }

            await store.send(.failurePresentationChanged(false))
        }

        // A save that fails in the background must not interrupt the form on screen
        @Test
        func aFailedSaveWaitsForThePresentedForm() async {
            var state = makeReadyState()
            state.expenses.destination = .createExpense(ExpenseForm.State())

            let store = TestStore(initialState: state) {
                Tabs()
            }

            await store.send(.expenses(.delegate(.didFailToSave))) {
                $0.failedOperations = [.saveExpense]
            }
            #expect(!store.state.isPresentingFailure)

            await store.send(.expenses(.destination(.dismiss))) {
                $0.expenses.destination = nil
            }
            #expect(store.state.isPresentingFailure)
        }

        // The deletion of one expense must not interrupt the creation of a different one
        @Test
        func aFailedDeletionWaitsForThePresentedForm() async {
            var state = makeReadyState()
            state.expenses.destination = .createExpense(ExpenseForm.State())

            let store = TestStore(initialState: state) {
                Tabs()
            }

            await store.send(.expenses(.delegate(.didFailToDelete))) {
                $0.failedOperations = [.deleteExpense]
            }
            #expect(!store.state.isPresentingFailure)

            await store.send(.expenses(.destination(.dismiss))) {
                $0.expenses.destination = nil
            }
            #expect(store.state.isPresentingFailure)
            expectNoDifference(store.state.failureMessage, "Your expense couldn't be deleted.")
        }

        @Test
        func aFailureWaitsForTheDetailPresentation() async {
            var state = makeReadyState()
            state.expenses.path.append(ExpenseDetail.State(expense: SharedReader(value: .rent)))
            let detailID = Array(state.expenses.path.ids)[0]
            state.expenses.path[id: detailID]?.destination = .alert(.confirmDeletion)

            let store = TestStore(initialState: state) {
                Tabs()
            }

            await store.send(.expenses(.delegate(.didFailToSave))) {
                $0.failedOperations = [.saveExpense]
            }
            #expect(!store.state.isPresentingFailure)

            await store.send(.expenses(.path(.element(id: detailID, action: .destination(.dismiss))))) {
                $0.expenses.path[id: detailID]?.destination = nil
            }
            #expect(store.state.isPresentingFailure)
        }

        @Test
        func aFailureWaitsForTheSettingsAlert() async {
            var state = makeReadyState()
            state.settings.alert = .confirmSignOut

            let store = TestStore(initialState: state) {
                Tabs()
            }

            await store.send(.expenses(.delegate(.didFailToSave))) {
                $0.failedOperations = [.saveExpense]
            }
            #expect(!store.state.isPresentingFailure)

            await store.send(.settings(.alert(.dismiss))) {
                $0.settings.alert = nil
            }
            #expect(store.state.isPresentingFailure)
        }

        @Test
        func aFailureWaitsForTheAccountDeletion() {
            var state = makeReadyState()
            state.failedOperations = [.saveExpense]

            state.settings.deletionStep = .deleting
            #expect(!state.isPresentingFailure)

            state.settings.deletionStep = nil
            #expect(state.isPresentingFailure)
        }

        @Test
        func aFailureWaitsForTheFirstExpenses() {
            var state = makeReadyState()
            state.failedOperations = [.saveExpense]

            state.expenses.$expenses.withLock { $0 = nil }
            #expect(!state.isPresentingFailure)

            state.expenses.$expenses.withLock { $0 = [] }
            #expect(state.isPresentingFailure)
        }

        @Test
        func aFailureWaitsForTheWelcome() {
            @Shared(.hasDismissedWelcome) var hasDismissedWelcome
            var state = makeReadyState()
            state.failedOperations = [.saveExpense]

            $hasDismissedWelcome.withLock { $0 = false }
            #expect(!state.isPresentingFailure)

            $hasDismissedWelcome.withLock { $0 = true }
            #expect(state.isPresentingFailure)
        }

        private func makeReadyState() -> Tabs.State {
            @Shared(.hasDismissedWelcome) var hasDismissedWelcome
            $hasDismissedWelcome.withLock { $0 = true }
            let state = Tabs.State(user: .mock)
            state.expenses.$expenses.withLock { $0 = [] }
            return state
        }
    }
}
