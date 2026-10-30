//
//  InvestmentFormTests.swift
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
    struct InvestmentFormTests {
        @Test
        func aNewInvestmentStartsEmptyAndFocused() {
            let state = InvestmentForm.State(income: 3000, investment: nil)

            expectNoDifference(state.focus, .investment)
            expectNoDifference(state.investment.text, "")
            #expect(!state.isEditing)
            expectNoDifference(state.investment.value, nil)
            #expect(!state.investment.input.isInvalid)
        }

        @Test
        func anExistingInvestmentStartsFormattedAndFocused() {
            let english = InvestmentForm.State(income: 3000, investment: 450)
            expectNoDifference(english.focus, .investment)
            expectNoDifference(english.investment.text, "450")
            #expect(english.isEditing)
            expectNoDifference(english.share, Decimal(string: "0.15"))

            let italian = withDependencies {
                $0.locale = Locale(identifier: "it_IT")
            } operation: {
                InvestmentForm.State(income: 3000, investment: 450)
            }
            expectNoDifference(italian.investment.text, "450")
        }

        @Test
        func theInvestmentIsAtMostTheIncome() {
            var state = InvestmentForm.State(income: 3000, investment: nil)

            state.investment.text = "3000"
            expectNoDifference(state.investment.value, 3000)
            #expect(!state.exceedsIncome)

            state.investment.text = "3001"
            expectNoDifference(state.investment.input, .overLimit(3001))
            expectNoDifference(state.investment.value, nil)
            #expect(state.exceedsIncome)
            expectNoDifference(state.share, nil)
        }

        @Test(arguments: ["0", "-10", "12abc", "1e3", "12.5"])
        func anInvalidInvestmentIsRefused(text: String) {
            var state = InvestmentForm.State(income: 3000, investment: nil)
            state.investment.text = text

            expectNoDifference(state.investment.value, nil)
            #expect(!state.exceedsIncome)
            #expect(state.investment.input.isInvalid)
        }

        @Test
        func aShareButtonFillsInAWholeInvestment() async {
            let store = TestStore(initialState: InvestmentForm.State(income: 1234, investment: nil)) {
                InvestmentForm()
            }

            await store.send(.shareButtonTapped(15)) {
                $0.investment.text = "185"
            }
            await store.send(.shareButtonTapped(20)) {
                $0.investment.text = "247"
            }
        }

        @Test
        func theInvestmentSelectsTheMatchingShare() {
            var state = InvestmentForm.State(income: 3200, investment: nil)
            expectNoDifference(state.selectedSharePercent, nil)

            state.investment.text = "480"
            expectNoDifference(state.selectedSharePercent, 15)

            state.investment.text = "481"
            expectNoDifference(state.selectedSharePercent, nil)
        }

        @Test
        func aRoundedShareIsStillSelected() {
            var state = InvestmentForm.State(income: 1030, investment: nil)
            state.investment.text = "155"

            expectNoDifference(state.selectedSharePercent, 15)
        }

        @Test
        func onlyTextThatCannotBecomeValidIsRefused() {
            var state = InvestmentForm.State(income: 3200, investment: nil)
            state.investment.text = "0"
            #expect(state.investment.input.isInvalid)
            #expect(!state.investment.input.isRefused)

            state.investment.text = "1.2"
            #expect(state.investment.input.isRefused)

            state.investment.text = "4000"
            #expect(state.investment.input.isRefused)
        }

        @Test
        func aShareButtonRoundsAHalfUp() async {
            let store = TestStore(initialState: InvestmentForm.State(income: 1030, investment: nil)) {
                InvestmentForm()
            }

            await store.send(.shareButtonTapped(15)) {
                $0.investment.text = "155"
            }
        }

        @Test
        func aShareButtonDoesNothingWhenTheShareRoundsToZero() async {
            let store = TestStore(initialState: InvestmentForm.State(income: 4, investment: nil)) {
                InvestmentForm()
            }

            await store.send(.shareButtonTapped(10))
        }

        @Test
        func aShareButtonWritesTheInvestmentInTheLocaleFormat() async {
            let state = withDependencies {
                $0.locale = Locale(identifier: "it_IT")
            } operation: {
                InvestmentForm.State(income: 3000, investment: nil)
            }
            let store = TestStore(initialState: state) {
                InvestmentForm()
            }

            await store.send(.shareButtonTapped(15)) {
                $0.investment.text = "450"
            }
        }

        @Test
        func savingSubmitsTheInvestment() async {
            let store = TestStore(initialState: InvestmentForm.State(income: 3000, investment: nil)) {
                InvestmentForm()
            }

            await store.send(.investment(.binding(.set(\.text, "450")))) {
                $0.investment.text = "450"
            }
            await store.send(.saveButtonTapped)
            await store.receive(\.delegate.didSubmit, 450)
        }

        @Test
        func savingAnInvestmentAboveTheIncomeDoesNothing() async {
            let store = TestStore(initialState: InvestmentForm.State(income: 3000, investment: 450)) {
                InvestmentForm()
            }

            await store.send(.investment(.binding(.set(\.text, "3500")))) {
                $0.investment.text = "3500"
            }
            await store.send(.saveButtonTapped)
        }

        @Test
        func removingTheInvestmentAsksForConfirmation() async {
            let store = TestStore(initialState: InvestmentForm.State(income: 3000, investment: 450)) {
                InvestmentForm()
            }

            await store.send(.removeButtonTapped) {
                $0.destination = .alert(
                    AlertState {
                        TextState("Remove Savings")
                    } actions: {
                        ButtonState(role: .destructive, action: .confirmRemoval) {
                            TextState("Remove")
                        }
                        ButtonState(role: .cancel) {
                            TextState("Cancel")
                        }
                    } message: {
                        TextState("Your savings will be removed. Your income and expenses will stay.")
                    })
            }
            await store.send(.destination(.presented(.alert(.confirmRemoval)))) {
                $0.destination = nil
            }
            await store.receive(\.delegate.didRemove)
        }

        @Test
        func cancelingTheRemovalKeepsTheInvestment() async {
            let store = TestStore(initialState: InvestmentForm.State(income: 3000, investment: 450)) {
                InvestmentForm()
            }

            await store.send(.removeButtonTapped) {
                $0.destination = .alert(.confirmRemoval)
            }
            await store.send(.destination(.dismiss)) {
                $0.destination = nil
            }
        }

        @Test
        func aNewInvestmentCannotBeRemoved() async {
            let store = TestStore(initialState: InvestmentForm.State(income: 3000, investment: nil)) {
                InvestmentForm()
            }

            await store.send(.removeButtonTapped)
        }

        @Test
        func dismissingWithoutChangesClosesTheForm() async {
            await confirmation("Dismisses the form") { dismissesForm in
                let store = TestStore(initialState: InvestmentForm.State(income: 3000, investment: 450)) {
                    InvestmentForm()
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
                let store = TestStore(initialState: InvestmentForm.State(income: 3000, investment: 450)) {
                    InvestmentForm()
                } withDependencies: {
                    $0.dismiss = DismissEffect { dismissesForm() }
                }

                await store.send(.shareButtonTapped(10)) {
                    $0.investment.text = "300"
                }
                await store.send(.dismissButtonTapped)
                await store.finish()
            }
        }
    }
}
