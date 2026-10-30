//
//  ExpenseDetailTests.swift
//  OverheadTests
//
//  Created by Lorenzo Mazzarotto on 30/08/26.
//

import ComposableArchitecture
import Foundation
import Testing

@testable import Overhead

extension BaseSuite {
    @Suite
    @MainActor
    struct ExpenseDetailTests {
        // The form starts from the expense, so it edits and does not create
        @Test
        func theEditButtonOpensTheFormOnTheExpense() async {
            let store = TestStore(
                initialState: ExpenseDetail.State(expense: SharedReader(value: .rent))
            ) {
                ExpenseDetail()
            }

            await store.send(.editButtonTapped) {
                $0.destination = .editExpense(ExpenseForm.State(expense: .rent))
            }
        }

        @Test
        func theActiveToggleTellsTheParent() async {
            let store = TestStore(
                initialState: ExpenseDetail.State(expense: SharedReader(value: .rent))
            ) {
                ExpenseDetail()
            }
            var inactive = Expense.rent
            inactive.isActive = false

            await store.send(.activeToggleChanged(false))
            await store.receive(\.delegate.didUpdate, inactive)
        }

        @Test
        func theActiveToggleIgnoresTheCurrentStatus() async {
            let store = TestStore(
                initialState: ExpenseDetail.State(expense: SharedReader(value: .rent))
            ) {
                ExpenseDetail()
            }

            await store.send(.activeToggleChanged(true))
        }

        // The detail closes the form itself, and Expenses receives the expense to save
        @Test
        func savingTheEditedExpenseClosesTheFormAndTellsTheParent() async {
            await confirmation("Plays the success haptic") { playsHaptic in
                let store = TestStore(
                    initialState: ExpenseDetail.State(
                        destination: .editExpense(ExpenseForm.State(expense: .rent)),
                        expense: SharedReader(value: .rent)
                    )
                ) {
                    ExpenseDetail()
                } withDependencies: {
                    $0.hapticsClient.success = { playsHaptic() }
                }
                var edited = Expense.rent
                edited.amount = 1000

                await store.send(
                    .destination(.presented(.editExpense(.amount(.binding(.set(\.text, "1000"))))))
                ) {
                    $0.destination?.modify(\.editExpense) { $0.amount.text = "1000" }
                }
                await store.send(.destination(.presented(.editExpense(.saveButtonTapped))))
                await store.receive(\.destination.presented.editExpense.delegate.didSubmit, edited) {
                    $0.destination = nil
                }
                await store.receive(\.delegate.didUpdate, edited)
            }
        }

        // The expense disappears from every device
        @Test
        func theDeleteButtonAsksForConfirmation() async {
            let store = TestStore(
                initialState: ExpenseDetail.State(expense: SharedReader(value: .rent))
            ) {
                ExpenseDetail()
            }

            await store.send(.deleteButtonTapped) {
                $0.destination = .alert(.confirmDeletion)
            }
        }

        // The detail cannot delete because Expenses holds the expenses
        @Test
        func confirmingTheDeletionTellsTheParent() async {
            let store = TestStore(
                initialState: ExpenseDetail.State(
                    destination: .alert(.confirmDeletion),
                    expense: SharedReader(value: .rent)
                )
            ) {
                ExpenseDetail()
            }

            await store.send(.destination(.presented(.alert(.confirmDeletion)))) {
                $0.destination = nil
            }
            await store.receive(\.delegate.didDelete, Expense.rent.id)
        }

        // A dismissed alert must not reach the parent
        @Test
        func cancelingTheDeletionKeepsTheExpense() async {
            let store = TestStore(
                initialState: ExpenseDetail.State(
                    destination: .alert(.confirmDeletion),
                    expense: SharedReader(value: .rent)
                )
            ) {
                ExpenseDetail()
            }

            await store.send(.destination(.dismiss)) {
                $0.destination = nil
            }
        }
    }
}
