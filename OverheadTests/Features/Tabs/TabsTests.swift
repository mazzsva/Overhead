//
//  TabsTests.swift
//  OverheadTests
//
//  Created by Lorenzo Mazzarotto on 01/10/26.
//

import ComposableArchitecture
import CustomDump
import Testing

@testable import Overhead

extension BaseSuite {
    @Suite
    @MainActor
    struct TabsTests {
        @Test
        func aFailedSaveShowsAnAlert() async {
            let state = makeReadyState()

            let store = TestStore(initialState: state) {
                Tabs()
            }

            await store.send(.expenses(.delegate(.didFailToSave))) {
                $0.failedExpenseOperations = [.save]
            }
            #expect(store.state.isPresentingExpenseFailure)
            expectNoDifference(store.state.expenseFailureMessage, "Your expense couldn't be saved.")
        }

        @Test
        func differentFailuresShowACombinedMessage() async {
            let state = makeReadyState()

            let store = TestStore(initialState: state) {
                Tabs()
            }

            await store.send(.expenses(.delegate(.didFailToSave))) {
                $0.failedExpenseOperations = [.save]
            }
            await store.send(.expenses(.delegate(.didFailToSave)))
            await store.send(.expenses(.delegate(.didFailToDelete))) {
                $0.failedExpenseOperations = [.delete, .save]
            }
            expectNoDifference(
                store.state.expenseFailureMessage,
                "Some of your changes couldn't be saved."
            )
        }

        @Test
        func dismissingTheAlertClearsTheFailures() async {
            var state = makeReadyState()
            state.failedExpenseOperations = [.delete, .save]

            let store = TestStore(initialState: state) {
                Tabs()
            }

            await store.send(.expenseFailurePresentationChanged(false)) {
                $0.failedExpenseOperations = []
            }
        }

        @Test
        func aHiddenAlertKeepsTheFailures() async {
            var state = makeReadyState()
            state.failedExpenseOperations = [.save]
            state.settings.alert = .signOutFailed

            let store = TestStore(initialState: state) {
                Tabs()
            }

            await store.send(.expenseFailurePresentationChanged(false))
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
                $0.failedExpenseOperations = [.save]
            }
            #expect(!store.state.isPresentingExpenseFailure)

            await store.send(.expenses(.destination(.dismiss))) {
                $0.expenses.destination = nil
            }
            #expect(store.state.isPresentingExpenseFailure)
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
                $0.failedExpenseOperations = [.delete]
            }
            #expect(!store.state.isPresentingExpenseFailure)

            await store.send(.expenses(.destination(.dismiss))) {
                $0.expenses.destination = nil
            }
            #expect(store.state.isPresentingExpenseFailure)
            expectNoDifference(store.state.expenseFailureMessage, "Your expense couldn't be deleted.")
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
                $0.failedExpenseOperations = [.save]
            }
            #expect(!store.state.isPresentingExpenseFailure)

            await store.send(.expenses(.path(.element(id: detailID, action: .destination(.dismiss))))) {
                $0.expenses.path[id: detailID]?.destination = nil
            }
            #expect(store.state.isPresentingExpenseFailure)
        }

        @Test
        func aFailureWaitsForTheSettingsAlert() async {
            var state = makeReadyState()
            state.settings.alert = .confirmSignOut

            let store = TestStore(initialState: state) {
                Tabs()
            }

            await store.send(.expenses(.delegate(.didFailToSave))) {
                $0.failedExpenseOperations = [.save]
            }
            #expect(!store.state.isPresentingExpenseFailure)

            await store.send(.settings(.alert(.dismiss))) {
                $0.settings.alert = nil
            }
            #expect(store.state.isPresentingExpenseFailure)
        }

        @Test
        func aFailureWaitsForTheAccountDeletion() {
            var state = makeReadyState()
            state.failedExpenseOperations = [.save]

            state.settings.deletionStep = .deleting
            #expect(!state.isPresentingExpenseFailure)

            state.settings.deletionStep = nil
            #expect(state.isPresentingExpenseFailure)
        }

        @Test
        func aFailureWaitsForTheFirstExpenses() {
            var state = makeReadyState()
            state.failedExpenseOperations = [.save]

            state.expenses.$expenses.withLock { $0 = nil }
            #expect(!state.isPresentingExpenseFailure)

            state.expenses.$expenses.withLock { $0 = [] }
            #expect(state.isPresentingExpenseFailure)
        }

        @Test
        func aFailureWaitsForTheWelcome() {
            @Shared(.hasDismissedWelcome) var hasDismissedWelcome
            var state = makeReadyState()
            state.failedExpenseOperations = [.save]

            $hasDismissedWelcome.withLock { $0 = false }
            #expect(!state.isPresentingExpenseFailure)

            $hasDismissedWelcome.withLock { $0 = true }
            #expect(state.isPresentingExpenseFailure)
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
