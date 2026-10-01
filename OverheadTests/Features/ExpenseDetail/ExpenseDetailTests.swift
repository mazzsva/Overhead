//
//  ExpenseDetailTests.swift
//  OverheadTests
//
//  Created by Lorenzo Mazzarotto on 30/08/26.
//

import ComposableArchitecture
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
                initialState: ExpenseDetail.State(expense: SharedReader(value: .blueMoon))
            ) {
                ExpenseDetail()
            }

            await store.send(.editButtonTapped) {
                $0.destination = .editExpense(ExpenseForm.State(expense: .blueMoon))
            }
        }

        // The detail closes the form itself, and home receives the expense to save
        @Test
        func savingTheEditedExpenseClosesTheFormAndTellsTheParent() async {
            await confirmation("Plays the success haptic") { playsHaptic in
                let store = TestStore(
                    initialState: ExpenseDetail.State(
                        destination: .editExpense(ExpenseForm.State(expense: .blueMoon)),
                        expense: SharedReader(value: .blueMoon)
                    )
                ) {
                    ExpenseDetail()
                } withDependencies: {
                    $0.hapticsClient.success = { playsHaptic() }
                }
                store.exhaustivity = .off

                var edited = Expense.blueMoon
                edited.definition = "Something that almost never happens."

                await store.send(
                    .destination(.presented(.editExpense(.binding(.set(\.definition, edited.definition)))))
                )
                await store.send(.destination(.presented(.editExpense(.saveButtonTapped))))
                await store.receive(\.delegate.didUpdate, edited) {
                    $0.destination = nil
                }
            }
        }

        // The expense disappears from every device
        @Test
        func theDeleteButtonAsksForConfirmation() async {
            let store = TestStore(
                initialState: ExpenseDetail.State(expense: SharedReader(value: .blueMoon))
            ) {
                ExpenseDetail()
            }

            await store.send(.deleteButtonTapped) {
                $0.destination = .alert(.confirmDeletion)
            }
        }

        // The detail cannot delete because home holds the expenses
        @Test
        func confirmingTheDeletionTellsTheParent() async {
            let store = TestStore(
                initialState: ExpenseDetail.State(
                    destination: .alert(.confirmDeletion),
                    expense: SharedReader(value: .blueMoon)
                )
            ) {
                ExpenseDetail()
            }

            await store.send(.destination(.presented(.alert(.confirmDeletion)))) {
                $0.destination = nil
            }
            await store.receive(\.delegate.didDelete, Expense.blueMoon.id)
        }

        // A dismissed alert must not reach the parent
        @Test
        func cancelingTheDeletionKeepsTheExpense() async {
            let store = TestStore(
                initialState: ExpenseDetail.State(
                    destination: .alert(.confirmDeletion),
                    expense: SharedReader(value: .blueMoon)
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
