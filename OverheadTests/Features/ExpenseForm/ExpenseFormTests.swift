//
//  ExpenseFormTests.swift
//  OverheadTests
//
//  Created by Lorenzo Mazzarotto on 31/08/26.
//

import ComposableArchitecture
import Foundation
import Testing

@testable import Overhead

extension BaseSuite {
    @Suite
    @MainActor
    struct ExpenseFormTests {
        // An expense needs a term, and the definition can stay empty
        @Test
        func onlyANonBlankTermIsSubmittable() {
            var state = ExpenseForm.State()
            #expect(state.isCreating)
            #expect(!state.isSubmittable)

            state.term = "   \n  "
            #expect(!state.isSubmittable)

            state.term = "Burn the candle at both ends"
            #expect(state.isSubmittable)
        }

        // The form gives the expense an identity, so the save does not wait for the server
        @Test
        func creatingAnExpenseGeneratesItsIdentityAndDate() async {
            let now = Date(timeIntervalSince1970: 1_751_000_000)
            let created = Expense(
                createdAt: now,
                definition: "The easiest wins, taken first.",
                id: UUID(0),
                term: "Low-hanging fruit"
            )

            let store = TestStore(initialState: ExpenseForm.State()) {
                ExpenseForm()
            } withDependencies: {
                $0.date.now = now
                $0.uuid = .incrementing
            }

            await store.send(.binding(.set(\.term, "  Low-hanging fruit  "))) {
                $0.term = "  Low-hanging fruit  "
            }
            await store.send(.binding(.set(\.definition, created.definition))) {
                $0.definition = created.definition
            }
            await store.send(.saveButtonTapped)
            await store.receive(\.delegate.didSubmit, created)
        }

        // The identity and the date come from the original, so the save replaces it
        @Test
        func editingAnExpenseKeepsItsIdentity() async {
            var edited = Expense.blueMoon
            edited.definition = "A rare event."

            let store = TestStore(initialState: ExpenseForm.State(expense: .blueMoon)) {
                ExpenseForm()
            }

            await store.send(.binding(.set(\.definition, "  A rare event.  "))) {
                $0.definition = "  A rare event.  "
            }
            await store.send(.saveButtonTapped)
            await store.receive(\.delegate.didSubmit, edited)
        }

        // The view disables the save button, and the reducer refuses the term as well
        @Test
        func savingABlankTermDoesNothing() async {
            let store = TestStore(initialState: ExpenseForm.State()) {
                ExpenseForm()
            }

            await store.send(.binding(.set(\.term, "   "))) {
                $0.term = "   "
            }
            await store.send(.saveButtonTapped)
        }

        // The parent presents the form, so only the dismiss effect can close it
        @Test
        func theDismissButtonClosesTheForm() async {
            await confirmation("Dismisses the form") { dismissesForm in
                let store = TestStore(initialState: ExpenseForm.State(expense: .blueMoon)) {
                    ExpenseForm()
                } withDependencies: {
                    $0.dismiss = DismissEffect { dismissesForm() }
                }

                await store.send(.dismissButtonTapped)
                await store.finish()
            }
        }
    }
}
