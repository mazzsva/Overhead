//
//  HomeTests.swift
//  OverheadTests
//
//  Created by Lorenzo Mazzarotto on 01/10/26.
//

import AccountKit
import ComposableArchitecture
import CustomDump
import Foundation
import Testing

@testable import Overhead

extension BaseSuite {
    @Suite
    @MainActor
    struct HomeTests {
        @Test
        func theOverviewFollowsTheExpenses() async {
            let store = TestStore(initialState: Home.State(user: .mock)) {
                Home()
            }
            expectNoDifference(store.state.overview.annualExpenses, nil)

            await store.send(.expenses(.expensesUpdated(Expense.mocks))) {
                $0.expenses.$expenses.withLock { $0 = IdentifiedArray(uniqueElements: Expense.mocks) }
            }
            expectNoDifference(store.state.overview.annualExpenses, 11880)

            var pausedRent = Expense.rent
            pausedRent.isActive = false
            await store.send(.expenses(.expensesUpdated([pausedRent, .gym, .phonePlan]))) {
                $0.expenses.$expenses.withLock {
                    $0 = IdentifiedArray(uniqueElements: [pausedRent, .gym, .phonePlan])
                }
            }
            expectNoDifference(store.state.overview.annualExpenses, 480)
        }

        @Test
        func theOverviewTaskObservesTheBudget() async {
            let budget = AsyncThrowingStream<BudgetSnapshot, any Error>.makeStream()

            let store = TestStore(initialState: Home.State(user: .mock)) {
                Home()
            } withDependencies: {
                $0.budgetClient.budget = { uid in
                    expectNoDifference(uid, AccountUser.mock.uid)
                    return budget.stream
                }
            }

            await store.send(.overview(.task))
            budget.continuation.yield(.known(.mock))
            await store.receive(\.overview.budgetUpdated) {
                $0.overview.budgetStatus = .loaded(.mock)
            }
            budget.continuation.finish()
            await store.finish()
        }

        @Test
        func theOverviewExpensesButtonPresentsTheExpenses() async {
            let store = TestStore(initialState: Home.State(user: .mock)) {
                Home()
            }

            await store.send(.overview(.expensesButtonTapped))
            await store.receive(\.overview.delegate.didSelectExpenses) {
                $0.screen = .expenses
            }
        }

        @Test
        func theOverviewSettingsButtonPresentsTheSettings() async {
            let store = TestStore(initialState: Home.State(user: .mock)) {
                Home()
            }

            await store.send(.overview(.settingsButtonTapped))
            await store.receive(\.overview.delegate.didSelectSettings) {
                $0.screen = .settings
            }
        }

        @Test(arguments: [Home.Screen.expenses, .settings])
        func dismissingAScreenHidesIt(screen: Home.Screen) async {
            var state = Home.State(user: .mock)
            state.screen = screen
            let store = TestStore(initialState: state) {
                Home()
            }

            await store.send(.screenChanged(nil)) {
                $0.screen = nil
            }
        }

        @Test
        func aFailedAccountDeletionBringsTheSettingsBackWithAnAlert() async {
            var state = Home.State(user: .mock)
            state.accountDeletion = AccountDeletion.State(uid: AccountUser.mock.uid)
            let store = TestStore(initialState: state) {
                Home()
            }

            await store.send(.accountDeletion(.presented(.delegate(.didFail(.notDeleted))))) {
                $0.accountDeletion = nil
                $0.settings.destination = .alert(.accountDeletionFailed(.notDeleted))
                $0.screen = .settings
            }
        }

        @Test
        func aCanceledAccountDeletionBringsTheSettingsBack() async {
            var state = Home.State(user: .mock)
            state.accountDeletion = AccountDeletion.State(uid: AccountUser.mock.uid)
            let store = TestStore(initialState: state) {
                Home()
            }

            await store.send(.accountDeletion(.presented(.delegate(.didCancel)))) {
                $0.accountDeletion = nil
                $0.screen = .settings
            }
        }

        @Test
        func aConfirmedAccountDeletionClosesTheSettingsAndStartsTheDeletion() async {
            var state = Home.State(user: .mock)
            state.screen = .settings
            let store = TestStore(initialState: state) {
                Home()
            } withDependencies: {
                $0.signInWithAppleClient.requestCredential = { try await Task.never() }
            }

            await store.send(.settings(.delegate(.didConfirmAccountDeletion))) {
                $0.screen = nil
                $0.accountDeletion = AccountDeletion.State(uid: AccountUser.mock.uid)
            }
            await store.receive(\.accountDeletion.presented.deletionConfirmed)
            await store.send(.accountDeletion(.dismiss)) {
                $0.accountDeletion = nil
            }
        }

        @Test
        func aSettingsAlertBringsTheSettingsBack() async {
            let store = TestStore(initialState: Home.State(user: .mock)) {
                Home()
            }

            await store.send(.settings(.signOutFailed(CancellationError()))) {
                $0.settings.destination = .alert(.signOutFailed)
                $0.screen = .settings
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
                Home()
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
                Home()
            }

            await store.send(.expenses(.delegate(.didFailToSave))) {
                $0.failedOperations = [.saveExpense]
            }
            #expect(store.state.isPresentingFailure)
            expectNoDifference(store.state.failureMessage, "Your expense couldn't be saved.")
        }

        @Test
        func aFailedCurrencySaveShowsAnAlert() async {
            let state = makeReadyState()

            let store = TestStore(initialState: state) {
                Home()
            }

            await store.send(.settings(.delegate(.didFailToSaveCurrency))) {
                $0.failedOperations = [.saveCurrency]
            }
            #expect(store.state.isPresentingFailure)
            expectNoDifference(store.state.failureMessage, "Your currency couldn't be saved.")
        }

        @Test
        func differentFailuresShowACombinedMessage() async {
            let state = makeReadyState()

            let store = TestStore(initialState: state) {
                Home()
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
                Home()
            }

            await store.send(.failurePresentationChanged(false)) {
                $0.failedOperations = []
            }
        }

        @Test
        func aHiddenAlertKeepsTheFailures() async {
            var state = makeReadyState()
            state.failedOperations = [.saveExpense]
            state.settings.destination = .alert(.signOutFailed)

            let store = TestStore(initialState: state) {
                Home()
            }

            await store.send(.failurePresentationChanged(false))
        }

        // A save that fails in the background must not interrupt the form on screen
        @Test
        func aFailedSaveWaitsForThePresentedForm() async {
            var state = makeReadyState()
            state.expenses.destination = .createExpense(ExpenseForm.State())

            let store = TestStore(initialState: state) {
                Home()
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
                Home()
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
                Home()
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
            state.settings.destination = .alert(.confirmSignOut)

            let store = TestStore(initialState: state) {
                Home()
            }

            await store.send(.expenses(.delegate(.didFailToSave))) {
                $0.failedOperations = [.saveExpense]
            }
            #expect(!store.state.isPresentingFailure)

            await store.send(.settings(.destination(.dismiss))) {
                $0.settings.destination = nil
            }
            #expect(store.state.isPresentingFailure)
        }

        @Test
        func aFailureWaitsForTheAccountDeletion() {
            var state = makeReadyState()
            state.failedOperations = [.saveExpense]

            state.accountDeletion = AccountDeletion.State(uid: AccountUser.mock.uid)
            #expect(!state.isPresentingFailure)

            state.accountDeletion = nil
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

        private func makeReadyState() -> Home.State {
            @Shared(.hasDismissedWelcome) var hasDismissedWelcome
            $hasDismissedWelcome.withLock { $0 = true }
            let state = Home.State(user: .mock)
            state.expenses.$expenses.withLock { $0 = [] }
            return state
        }
    }
}
