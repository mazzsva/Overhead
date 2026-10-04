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
            expectNoDifference(state.incomeText, "")
            expectNoDifference(state.investment, nil)
            #expect(!state.isEditing)
            #expect(!state.hasChanges)
        }

        @Test
        func anExistingIncomeStartsFormattedAndWithoutTheKeyboard() {
            let english = IncomeForm.State(budget: .mock)
            expectNoDifference(english.focus, nil)
            expectNoDifference(english.incomeText, "3000.00")
            expectNoDifference(english.investment, 450)
            #expect(english.isEditing)

            let italian = withDependencies {
                $0.locale = Locale(identifier: "it_IT")
            } operation: {
                IncomeForm.State(budget: .mock)
            }
            expectNoDifference(italian.incomeText, "3000,00")
        }

        @Test(arguments: ["0", "-10", "12abc", "1e3", "12.345"])
        func anInvalidIncomeIsRefused(text: String) {
            var state = IncomeForm.State(budget: nil)
            state.incomeText = text

            expectNoDifference(state.income, nil)
            #expect(state.isIncomeInvalid)
        }

        @Test
        func anEmptyIncomeIsNotYetInvalid() {
            var state = IncomeForm.State(budget: nil)
            state.incomeText = "  "

            expectNoDifference(state.income, nil)
            #expect(!state.isIncomeInvalid)

            state.incomeText = " 3,000.50 "
            expectNoDifference(state.income, Decimal(cents: 300_050))
        }

        @Test
        func savingSubmitsTheIncome() async {
            let store = TestStore(initialState: IncomeForm.State(budget: .mock)) {
                IncomeForm()
            }

            await store.send(.binding(.set(\.incomeText, "3500"))) {
                $0.incomeText = "3500"
            }
            await store.send(.saveButtonTapped)
            await store.receive(\.delegate.didSubmit, 3500)
        }

        @Test
        func anIncomeBelowTheInvestmentAsksToRemoveTheInvestment() async {
            let store = TestStore(initialState: IncomeForm.State(budget: .mock)) {
                IncomeForm()
            }

            await store.send(.binding(.set(\.incomeText, "400"))) {
                $0.incomeText = "400"
            }
            #expect(store.state.isBelowInvestment)
            await store.send(.saveButtonTapped) {
                $0.alert = AlertState {
                    TextState("Remove Investments?")
                } actions: {
                    ButtonState(role: .destructive, action: .confirmRemovingInvestment) {
                        TextState("Remove Investments and Save")
                    }
                    ButtonState(role: .cancel) {
                        TextState("Cancel")
                    }
                } message: {
                    TextState("Your investments of $450.00 are more than this income.")
                }
            }
            await store.send(.alert(.presented(.confirmRemovingInvestment))) {
                $0.alert = nil
            }
            await store.receive(\.delegate.didSubmitRemovingInvestment, 400)
        }

        @Test
        func removingTheIncomeAsksForConfirmationThatMentionsTheInvestment() async {
            let store = TestStore(initialState: IncomeForm.State(budget: .mock)) {
                IncomeForm()
            }

            await store.send(.removeButtonTapped) {
                $0.alert = AlertState {
                    TextState("Remove Income")
                } actions: {
                    ButtonState(role: .destructive, action: .confirmRemoval) {
                        TextState("Remove")
                    }
                    ButtonState(role: .cancel) {
                        TextState("Cancel")
                    }
                } message: {
                    TextState("Your income and investments will be removed. Your expenses will stay.")
                }
            }
            await store.send(.alert(.presented(.confirmRemoval))) {
                $0.alert = nil
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
                $0.alert = AlertState {
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
                }
            }
            await store.send(.alert(.dismiss)) {
                $0.alert = nil
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
        func dismissingWithChangesAsksToDiscardThem() async {
            await confirmation("Dismisses the form") { dismissesForm in
                let store = TestStore(initialState: IncomeForm.State(budget: .mock)) {
                    IncomeForm()
                } withDependencies: {
                    $0.dismiss = DismissEffect { dismissesForm() }
                }

                await store.send(.binding(.set(\.incomeText, "3500"))) {
                    $0.incomeText = "3500"
                }
                #expect(store.state.hasChanges)
                await store.send(.dismissButtonTapped) {
                    $0.alert = AlertState {
                        TextState("Discard Changes?")
                    } actions: {
                        ButtonState(role: .destructive, action: .confirmDiscard) {
                            TextState("Discard Changes")
                        }
                        ButtonState(role: .cancel) {
                            TextState("Keep Editing")
                        }
                    }
                }
                await store.send(.alert(.presented(.confirmDiscard))) {
                    $0.alert = nil
                }
                await store.finish()
            }
        }
    }
}
