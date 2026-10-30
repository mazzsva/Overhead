//
//  IncomeFormTests.swift
//  OverheadTests
//
//  Created by Lorenzo Mazzarotto on 04/10/26.
//

import ComposableArchitecture
import CustomDump
import Foundation
import Testing

@testable import Overhead

extension BaseSuite {
    @Suite
    @MainActor
    struct IncomeFormTests {
        @Test
        func aNewIncomeStartsEmptyAndFocused() {
            let state = IncomeForm.State(budget: nil)

            expectNoDifference(state.focus, .income)
            expectNoDifference(state.income.text, "")
            expectNoDifference(state.investment, nil)
            #expect(!state.isEditing)
        }

        @Test
        func onlyTextThatCannotBecomeValidIsRefused() {
            var state = IncomeForm.State(budget: nil)
            state.income.text = "0"
            #expect(state.income.input.isInvalid)
            #expect(!state.income.input.isRefused)

            state.income.text = "1.2"
            #expect(state.income.input.isRefused)

            state.income.text = "1000000000"
            #expect(state.income.input.isRefused)
        }

        @Test
        func anExistingIncomeStartsFormattedAndFocused() {
            let english = IncomeForm.State(budget: .mock)
            expectNoDifference(english.focus, .income)
            expectNoDifference(english.income.text, "3000")
            expectNoDifference(english.investment, 450)
            #expect(english.isEditing)

            let italian = withDependencies {
                $0.locale = Locale(identifier: "it_IT")
            } operation: {
                IncomeForm.State(budget: .mock)
            }
            expectNoDifference(italian.income.text, "3000")
        }

        @Test(arguments: ["0", "-10", "12abc", "1e3", "12.5", "1000000000"])
        func anInvalidIncomeIsRefused(text: String) {
            var state = IncomeForm.State(budget: nil)
            state.income.text = text

            expectNoDifference(state.income.value, nil)
            #expect(state.income.input.isInvalid)
        }

        @Test
        func anEmptyIncomeIsNotYetInvalid() {
            var state = IncomeForm.State(budget: nil)
            state.income.text = "  "

            expectNoDifference(state.income.value, nil)
            #expect(!state.income.input.isInvalid)

            state.income.text = " 3,500 "
            expectNoDifference(state.income.value, 3500)
        }

        @Test
        func savingSubmitsTheIncome() async {
            let store = TestStore(initialState: IncomeForm.State(budget: .mock)) {
                IncomeForm()
            }

            await store.send(.income(.binding(.set(\.text, "3500")))) {
                $0.income.text = "3500"
            }
            await store.send(.saveButtonTapped)
            await store.receive(\.delegate.didSubmit, 3500)
        }

        @Test
        func anIncomeBelowTheInvestmentAsksToRemoveTheInvestment() async {
            let store = TestStore(initialState: IncomeForm.State(budget: .mock)) {
                IncomeForm()
            }

            await store.send(.income(.binding(.set(\.text, "400")))) {
                $0.income.text = "400"
            }
            #expect(store.state.isBelowInvestment)
            await store.send(.saveButtonTapped) {
                $0.destination = .alert(
                    AlertState {
                        TextState("Remove Savings")
                    } actions: {
                        ButtonState(role: .destructive, action: .confirmRemovingInvestment) {
                            TextState("Remove and Save")
                        }
                        ButtonState(role: .cancel) {
                            TextState("Cancel")
                        }
                    } message: {
                        TextState("Your savings of $450 are more than this income.")
                    })
            }
            await store.send(.destination(.presented(.alert(.confirmRemovingInvestment)))) {
                $0.destination = nil
            }
            await store.receive(\.delegate.didSubmitRemovingInvestment, 400)
        }

        @Test
        func removingTheIncomeAsksForConfirmationThatMentionsTheInvestment() async {
            let store = TestStore(initialState: IncomeForm.State(budget: .mock)) {
                IncomeForm()
            }

            await store.send(.removeButtonTapped) {
                $0.destination = .alert(
                    AlertState {
                        TextState("Remove Income")
                    } actions: {
                        ButtonState(role: .destructive, action: .confirmRemoval) {
                            TextState("Remove")
                        }
                        ButtonState(role: .cancel) {
                            TextState("Cancel")
                        }
                    } message: {
                        TextState("Your income and savings will be removed. Your expenses will stay.")
                    })
            }
            await store.send(.destination(.presented(.alert(.confirmRemoval)))) {
                $0.destination = nil
            }
            await store.receive(\.delegate.didRemove)
        }

        @Test
        func removingAnIncomeWithoutInvestmentMentionsOnlyTheIncome() async throws {
            let budget = try #require(Budget(income: 3000, investment: nil))
            let store = TestStore(initialState: IncomeForm.State(budget: budget)) {
                IncomeForm()
            }

            await store.send(.removeButtonTapped) {
                $0.destination = .alert(
                    AlertState {
                        TextState("Remove Income")
                    } actions: {
                        ButtonState(role: .destructive, action: .confirmRemoval) {
                            TextState("Remove")
                        }
                        ButtonState(role: .cancel) {
                            TextState("Cancel")
                        }
                    } message: {
                        TextState("Your income will be removed. Your expenses will stay.")
                    })
            }
            await store.send(.destination(.dismiss)) {
                $0.destination = nil
            }
        }

        @Test
        func aNewIncomeCannotBeRemoved() async {
            let store = TestStore(initialState: IncomeForm.State(budget: nil)) {
                IncomeForm()
            }

            await store.send(.removeButtonTapped)
        }

        @Test
        func dismissingWithoutChangesClosesTheForm() async {
            await confirmation("Dismisses the form") { dismissesForm in
                let store = TestStore(initialState: IncomeForm.State(budget: .mock)) {
                    IncomeForm()
                } withDependencies: {
                    $0.dismiss = DismissEffect { dismissesForm() }
                }

                await store.send(.dismissButtonTapped)
                await store.finish()
            }
        }

        @Test
        func dismissingWithChangesClosesTheForm() async {
            await confirmation("Dismisses the form") { dismissesForm in
                let store = TestStore(initialState: IncomeForm.State(budget: .mock)) {
                    IncomeForm()
                } withDependencies: {
                    $0.dismiss = DismissEffect { dismissesForm() }
                }

                await store.send(.income(.binding(.set(\.text, "3500")))) {
                    $0.income.text = "3500"
                }
                await store.send(.dismissButtonTapped)
                await store.finish()
            }
        }
    }
}
