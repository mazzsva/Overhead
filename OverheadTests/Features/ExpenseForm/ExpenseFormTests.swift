//
//  ExpenseFormTests.swift
//  OverheadTests
//
//  Created by Lorenzo Mazzarotto on 31/08/26.
//

import ComposableArchitecture
import CustomDump
import Foundation
import Testing

@testable import Overhead

extension BaseSuite {
    @Suite
    @MainActor
    struct ExpenseFormTests {
        // An expense needs a name and an amount above zero
        @Test
        func onlyANamedPositiveAmountIsSubmittable() {
            var state = ExpenseForm.State()
            #expect(state.isCreating)
            #expect(!state.isSubmittable)

            state.amountText = "12.50"
            state.name = "   \n  "
            #expect(!state.isSubmittable)

            state.name = "Gym"
            #expect(state.isSubmittable)

            state.amountText = "0"
            #expect(!state.isSubmittable)

            state.amountText = "-12.50"
            #expect(!state.isSubmittable)
        }

        @Test
        func theNameCannotBeLongerThanTheLimit() {
            var state = ExpenseForm.State()
            state.amountText = "12"

            state.name = String(repeating: "a", count: Expense.maximumNameLength)
            #expect(state.isSubmittable)

            state.name = String(repeating: "a", count: Expense.maximumNameLength + 1)
            #expect(!state.isSubmittable)

            state.name = "  " + String(repeating: "a", count: Expense.maximumNameLength) + "  "
            #expect(state.isSubmittable)

            state.name = String(repeating: "👍🏽", count: Expense.maximumNameLength / 4)
            #expect(state.isSubmittable)

            state.name = String(repeating: "👍🏽", count: Expense.maximumNameLength / 4 + 1)
            #expect(!state.isSubmittable)
        }

        @Test
        func theWholeAmountMustBeANumber() {
            var state = ExpenseForm.State()

            for text in ["12abc", "12,50", "1e3x", "1e3", ""] {
                state.amountText = text
                expectNoDifference(state.amount, nil)
            }

            state.amountText = " 1,200.50 "
            expectNoDifference(state.amount, Decimal(cents: 120_050))
        }

        @Test
        func theAmountCannotHaveMoreThanTwoDecimalPlaces() {
            var state = ExpenseForm.State()

            state.amountText = "12.345"
            expectNoDifference(state.amount, nil)

            state.amountText = "12.34"
            expectNoDifference(state.amount, Decimal(cents: 1234))
        }

        @Test
        func theLocaleDecidesTheSeparators() {
            var state = withDependencies {
                $0.locale = Locale(identifier: "it_IT")
            } operation: {
                ExpenseForm.State()
            }

            state.amountText = "1.200,50"
            expectNoDifference(state.amount, Decimal(cents: 120_050))

            state.amountText = "1,200.50"
            expectNoDifference(state.amount, nil)
        }

        @Test
        func theFormStartsFromTheFormattedAmount() {
            let english = ExpenseForm.State(expense: .gym)
            expectNoDifference(english.amountText, "39.90")

            let italian = withDependencies {
                $0.locale = Locale(identifier: "it_IT")
            } operation: {
                ExpenseForm.State(expense: .rent)
            }
            expectNoDifference(italian.amountText, "950,00")
        }

        // The form gives the expense an identity, so the save does not wait for the server
        @Test
        func creatingAnExpenseGeneratesItsIdentityAndDate() async {
            let now = Date(timeIntervalSince1970: 1_751_000_000)
            let created = Expense(
                amount: Decimal(cents: 1299),
                billingCycle: .monthly,
                createdAt: now,
                id: UUID(0),
                isActive: true,
                name: "Phone Plan"
            )

            let store = TestStore(initialState: ExpenseForm.State()) {
                ExpenseForm()
            } withDependencies: {
                $0.date.now = now
                $0.uuid = .incrementing
            }

            await store.send(.binding(.set(\.name, "  Phone Plan  "))) {
                $0.name = "  Phone Plan  "
            }
            await store.send(.binding(.set(\.amountText, "12.99"))) {
                $0.amountText = "12.99"
            }
            await store.send(.saveButtonTapped)
            await store.receive(\.delegate.didSubmit, created)
        }

        // The identity and the date come from the original, so the save replaces it
        @Test
        func editingAnExpenseKeepsItsIdentity() async {
            var edited = Expense.rent
            edited.amount = 1000

            let store = TestStore(initialState: ExpenseForm.State(expense: .rent)) {
                ExpenseForm()
            }

            await store.send(.binding(.set(\.amountText, "1,000"))) {
                $0.amountText = "1,000"
            }
            await store.send(.saveButtonTapped)
            await store.receive(\.delegate.didSubmit, edited)
        }

        // The view disables the save button, and the reducer refuses the name as well
        @Test
        func savingABlankNameDoesNothing() async {
            let store = TestStore(initialState: ExpenseForm.State()) {
                ExpenseForm()
            }

            await store.send(.binding(.set(\.amountText, "12"))) {
                $0.amountText = "12"
            }
            await store.send(.binding(.set(\.name, "   "))) {
                $0.name = "   "
            }
            await store.send(.saveButtonTapped)
        }

        @Test
        func onlyANewExpenseFocusesTheName() {
            expectNoDifference(ExpenseForm.State().focus, .name)
            expectNoDifference(ExpenseForm.State(expense: .rent).focus, nil)
        }

        @Test
        func aNewExpenseStartsMonthlyAndActive() {
            let state = ExpenseForm.State()
            expectNoDifference(state.billingCycle, .monthly)
            #expect(state.isActive)
        }

        @Test
        func editingAnExpenseChangesItsDetails() async {
            var edited = Expense.rent
            edited.billingCycle = .yearly
            edited.isActive = false

            let store = TestStore(initialState: ExpenseForm.State(expense: .rent)) {
                ExpenseForm()
            }

            await store.send(.binding(.set(\.billingCycle, .yearly))) {
                $0.billingCycle = .yearly
            }
            await store.send(.binding(.set(\.isActive, false))) {
                $0.isActive = false
            }
            await store.send(.saveButtonTapped)
            await store.receive(\.delegate.didSubmit, edited)
        }

        // The parent presents the form, so only the dismiss effect can close it
        @Test
        func theDismissButtonClosesTheForm() async {
            await confirmation("Dismisses the form") { dismissesForm in
                let store = TestStore(initialState: ExpenseForm.State(expense: .rent)) {
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
