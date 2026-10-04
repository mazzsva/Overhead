//
//  BudgetFormTests.swift
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
    struct BudgetFormTests {
        @Test
        func aNewBudgetStartsEmpty() {
            let state = BudgetForm.State(budget: nil, focus: .income)

            expectNoDifference(state.focus, .income)
            expectNoDifference(state.incomeText, "")
            expectNoDifference(state.investmentText, "")
            expectNoDifference(state.budget, nil)
        }

        @Test
        func theFormStartsFromTheFormattedAmounts() {
            let english = BudgetForm.State(budget: .mock, focus: .investment)
            expectNoDifference(english.focus, .investment)
            expectNoDifference(english.incomeText, "3000.00")
            expectNoDifference(english.investmentText, "450.00")
            expectNoDifference(english.budget, .mock)

            let italian = withDependencies {
                $0.locale = Locale(identifier: "it_IT")
            } operation: {
                BudgetForm.State(budget: Budget(income: 3000, investment: nil), focus: .income)
            }
            expectNoDifference(italian.incomeText, "3000,00")
            expectNoDifference(italian.investmentText, "")
        }

        @Test
        func onlyAPositiveIncomeMakesABudget() {
            var state = BudgetForm.State(budget: nil, focus: .income)

            for text in ["", "0", "-10", "12abc", "1e3", "12.345"] {
                state.incomeText = text
                expectNoDifference(state.income, nil)
                expectNoDifference(state.budget, nil)
            }

            state.incomeText = " 3,000.50 "
            expectNoDifference(state.income, Decimal(cents: 300_050))
            expectNoDifference(state.budget, Budget(income: Decimal(cents: 300_050), investment: nil))
        }

        @Test
        func theInvestmentIsOptionalAndAtMostTheIncome() {
            var state = BudgetForm.State(budget: nil, focus: .income)
            state.incomeText = "3000"

            state.investmentText = "  "
            expectNoDifference(state.budget, Budget(income: 3000, investment: nil))
            expectNoDifference(state.investmentShare, nil)
            #expect(!state.isInvestmentInvalid)

            state.investmentText = "450"
            expectNoDifference(state.budget, .mock)
            expectNoDifference(state.investmentShare, Decimal(string: "0.15"))
            #expect(!state.investmentExceedsIncome)

            state.investmentText = "3000"
            expectNoDifference(state.budget, Budget(income: 3000, investment: 3000))
            #expect(!state.investmentExceedsIncome)

            state.investmentText = "3000.01"
            expectNoDifference(state.budget, nil)
            expectNoDifference(state.investmentShare, nil)
            #expect(state.investmentExceedsIncome)

            for text in ["0", "-10", "12abc", "1e3", "12.345"] {
                state.investmentText = text
                expectNoDifference(state.budget, nil)
                #expect(!state.investmentExceedsIncome)
                #expect(state.isInvestmentInvalid)
            }
        }

        @Test
        func aShareButtonFillsInTheInvestmentInCents() async {
            let store = TestStore(initialState: BudgetForm.State(budget: nil, focus: .income)) {
                BudgetForm()
            }

            await store.send(.investmentShareButtonTapped(10))

            await store.send(.binding(.set(\.incomeText, "1234.56"))) {
                $0.incomeText = "1234.56"
            }
            await store.send(.investmentShareButtonTapped(15)) {
                $0.investmentText = "185.18"
            }
            await store.send(.investmentShareButtonTapped(20)) {
                $0.investmentText = "246.91"
            }
            await store.send(.binding(.set(\.incomeText, "10.30"))) {
                $0.incomeText = "10.30"
            }
            await store.send(.investmentShareButtonTapped(15)) {
                $0.investmentText = "1.55"
            }
        }

        @Test
        func aShareButtonDoesNothingWhenTheShareRoundsToZero() async {
            let store = TestStore(initialState: BudgetForm.State(budget: nil, focus: .income)) {
                BudgetForm()
            }

            await store.send(.binding(.set(\.incomeText, "0.01"))) {
                $0.incomeText = "0.01"
            }
            await store.send(.investmentShareButtonTapped(10))
        }

        @Test
        func aShareButtonWritesTheInvestmentInTheLocaleFormat() async {
            let state = withDependencies {
                $0.locale = Locale(identifier: "it_IT")
            } operation: {
                BudgetForm.State(budget: Budget(income: 3000, investment: nil), focus: .investment)
            }
            let store = TestStore(initialState: state) {
                BudgetForm()
            }

            await store.send(.investmentShareButtonTapped(15)) {
                $0.investmentText = "450,00"
            }
        }

        @Test
        func savingSubmitsTheBudget() async {
            let store = TestStore(initialState: BudgetForm.State(budget: nil, focus: .income)) {
                BudgetForm()
            }

            await store.send(.binding(.set(\.incomeText, "3000"))) {
                $0.incomeText = "3000"
            }
            await store.send(.binding(.set(\.investmentText, "450"))) {
                $0.investmentText = "450"
            }
            await store.send(.saveButtonTapped)
            await store.receive(\.delegate.didSubmit, .mock)
        }

        @Test
        func clearingTheInvestmentSubmitsABudgetWithoutIt() async {
            let store = TestStore(initialState: BudgetForm.State(budget: .mock, focus: .investment)) {
                BudgetForm()
            }

            await store.send(.binding(.set(\.investmentText, ""))) {
                $0.investmentText = ""
            }
            await store.send(.saveButtonTapped)
            await store.receive(\.delegate.didSubmit, Budget(income: 3000, investment: nil))
        }

        @Test
        func savingAnInvestmentAboveTheIncomeDoesNothing() async {
            let store = TestStore(initialState: BudgetForm.State(budget: .mock, focus: .investment)) {
                BudgetForm()
            }

            await store.send(.binding(.set(\.investmentText, "3500"))) {
                $0.investmentText = "3500"
            }
            await store.send(.saveButtonTapped)
        }

        @Test
        func theDismissButtonClosesTheForm() async {
            await confirmation("Dismisses the form") { dismissesForm in
                let store = TestStore(initialState: BudgetForm.State(budget: .mock, focus: .income)) {
                    BudgetForm()
                } withDependencies: {
                    $0.dismiss = DismissEffect { dismissesForm() }
                }

                await store.send(.dismissButtonTapped)
                await store.finish()
            }
        }
    }
}
