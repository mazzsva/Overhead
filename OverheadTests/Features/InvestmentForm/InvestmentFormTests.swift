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
            expectNoDifference(state.investmentText, "")
            #expect(!state.isEditing)
            #expect(!state.isSubmittable)
            #expect(!state.isInvestmentInvalid)
            #expect(!state.hasChanges)
        }

        @Test
        func anExistingInvestmentStartsFormattedAndWithoutTheKeyboard() {
            let english = InvestmentForm.State(income: 3000, investment: 450)
            expectNoDifference(english.focus, nil)
            expectNoDifference(english.investmentText, "450.00")
            #expect(english.isEditing)
            expectNoDifference(english.share, Decimal(string: "0.15"))

            let italian = withDependencies {
                $0.locale = Locale(identifier: "it_IT")
            } operation: {
                InvestmentForm.State(income: 3000, investment: 450)
            }
            expectNoDifference(italian.investmentText, "450,00")
        }

        @Test
        func theInvestmentIsAtMostTheIncome() {
            var state = InvestmentForm.State(income: 3000, investment: nil)

            state.investmentText = "3000"
            #expect(state.isSubmittable)
            #expect(!state.exceedsIncome)

            state.investmentText = "3000.01"
            #expect(!state.isSubmittable)
            #expect(state.exceedsIncome)
            expectNoDifference(state.share, nil)
        }

        @Test(arguments: ["0", "-10", "12abc", "1e3", "12.345"])
        func anInvalidInvestmentIsRefused(text: String) {
            var state = InvestmentForm.State(income: 3000, investment: nil)
            state.investmentText = text

            #expect(!state.isSubmittable)
            #expect(!state.exceedsIncome)
            #expect(state.isInvestmentInvalid)
        }

        @Test
        func aShareButtonFillsInTheInvestmentInCents() async {
            let store = TestStore(
                initialState: InvestmentForm.State(income: Decimal(cents: 123_456), investment: nil)
            ) {
                InvestmentForm()
            }

            await store.send(.shareButtonTapped(15)) {
                $0.investmentText = "185.18"
            }
            await store.send(.shareButtonTapped(20)) {
                $0.investmentText = "246.91"
            }
        }

        @Test
        func aShareButtonRoundsHalfACentUp() async {
            let store = TestStore(initialState: InvestmentForm.State(income: Decimal(cents: 1030), investment: nil)) {
                InvestmentForm()
            }

            await store.send(.shareButtonTapped(15)) {
                $0.investmentText = "1.55"
            }
        }

        @Test
        func aShareButtonDoesNothingWhenTheShareRoundsToZero() async {
            let store = TestStore(initialState: InvestmentForm.State(income: Decimal(cents: 1), investment: nil)) {
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
                $0.investmentText = "450,00"
            }
        }

        @Test
        func onlyADifferentAmountCountsAsAChange() {
            var state = InvestmentForm.State(income: 3000, investment: 450)

            state.investmentText = "450"
            #expect(!state.hasChanges)

            state.investmentText = "451"
            #expect(state.hasChanges)

            state.investmentText = ""
            #expect(state.hasChanges)

            var new = InvestmentForm.State(income: 3000, investment: nil)
            new.investmentText = " "
            #expect(!new.hasChanges)
        }

        @Test
        func savingSubmitsTheInvestment() async {
            let store = TestStore(initialState: InvestmentForm.State(income: 3000, investment: nil)) {
                InvestmentForm()
            }

            await store.send(.binding(.set(\.investmentText, "450"))) {
                $0.investmentText = "450"
            }
            await store.send(.saveButtonTapped)
            await store.receive(\.delegate.didSubmit, 450)
        }

        @Test
        func savingAnInvestmentAboveTheIncomeDoesNothing() async {
            let store = TestStore(initialState: InvestmentForm.State(income: 3000, investment: 450)) {
                InvestmentForm()
            }

            await store.send(.binding(.set(\.investmentText, "3500"))) {
                $0.investmentText = "3500"
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
        func dismissingWithChangesAsksToDiscardThem() async {
            let store = TestStore(initialState: InvestmentForm.State(income: 3000, investment: 450)) {
                InvestmentForm()
            }

            await store.send(.shareButtonTapped(10)) {
                $0.investmentText = "300.00"
            }
            await store.send(.dismissButtonTapped) {
                $0.destination = .confirmationDialog(.discardChanges(.confirmDiscard))
            }
            await store.send(.destination(.dismiss)) {
                $0.destination = nil
            }
        }
    }
}
