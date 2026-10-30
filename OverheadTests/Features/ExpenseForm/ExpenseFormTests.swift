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

            state.amount.text = "12"
            state.name.text = "   \n  "
            #expect(!state.isSubmittable)

            state.name.text = "Gym"
            #expect(state.isSubmittable)

            state.amount.text = "0"
            #expect(!state.isSubmittable)

            state.amount.text = "-12"
            #expect(!state.isSubmittable)
        }

        @Test
        func theNameCannotBeLongerThanTheLimit() {
            var state = ExpenseForm.State()
            state.amount.text = "12"

            state.name.text = String(repeating: "a", count: ExpenseName.maximumLength)
            #expect(state.isSubmittable)

            state.name.text = String(repeating: "a", count: ExpenseName.maximumLength + 1)
            #expect(!state.isSubmittable)

            state.name.text = "  " + String(repeating: "a", count: ExpenseName.maximumLength) + "  "
            #expect(state.isSubmittable)

            state.name.text = String(repeating: "👍🏽", count: ExpenseName.maximumLength / 4)
            #expect(state.isSubmittable)

            state.name.text = String(repeating: "👍🏽", count: ExpenseName.maximumLength / 4 + 1)
            #expect(!state.isSubmittable)
        }

        @Test
        func onlyANameOverTheLimitIsTooLong() {
            var state = ExpenseForm.State()
            expectNoDifference(state.name.input, .empty)

            state.name.text = "  " + String(repeating: "a", count: ExpenseName.maximumLength) + "  "
            expectNoDifference(state.name.value?.value, String(repeating: "a", count: ExpenseName.maximumLength))

            state.name.text = String(repeating: "a", count: ExpenseName.maximumLength + 1)
            expectNoDifference(state.name.input, .tooLong)
            #expect(state.name.input.isInvalid)

            state.name.text = "   "
            expectNoDifference(state.name.input, .empty)
            #expect(!state.name.input.isInvalid)
        }

        @Test
        func aBillingCycleButtonSelectsTheCycle() async {
            let store = TestStore(initialState: ExpenseForm.State()) {
                ExpenseForm()
            }

            await store.send(.billingCycleButtonTapped(.yearly)) {
                $0.billingCycle = .yearly
            }
            await store.send(.billingCycleButtonTapped(.monthly)) {
                $0.billingCycle = .monthly
            }
        }

        @Test
        func theWholeAmountMustBeANumber() {
            var state = ExpenseForm.State()

            for text in ["12abc", "12,50", "1e3x", "1e3", ""] {
                state.amount.text = text
                expectNoDifference(state.amount.value, nil)
            }

            state.amount.text = " 1,200 "
            expectNoDifference(state.amount.value, 1200)
        }

        @Test
        func theAmountIsAWholeNumber() {
            var state = ExpenseForm.State()

            for text in ["12.5", "12.0", "12.", ".5"] {
                state.amount.text = text
                expectNoDifference(state.amount.value, nil)
            }

            state.amount.text = "12"
            expectNoDifference(state.amount.value, 12)
        }

        @Test
        func theAmountIsAtMostTheLimit() {
            var state = ExpenseForm.State()

            state.amount.text = "999999999"
            expectNoDifference(state.amount.value, 999_999_999)

            state.amount.text = "1000000000"
            expectNoDifference(state.amount.value, nil)
        }

        @Test
        func theLocaleDecidesTheSeparators() {
            var state = withDependencies {
                $0.locale = Locale(identifier: "it_IT")
            } operation: {
                ExpenseForm.State()
            }

            state.amount.text = "1.200"
            expectNoDifference(state.amount.value, 1200)

            state.amount.text = "1,200"
            expectNoDifference(state.amount.value, nil)
        }

        @Test
        func theFormStartsFromTheFormattedAmount() {
            let english = ExpenseForm.State(expense: .gym)
            expectNoDifference(english.amount.text, "40")

            let italian = withDependencies {
                $0.locale = Locale(identifier: "it_IT")
            } operation: {
                ExpenseForm.State(expense: .rent)
            }
            expectNoDifference(italian.amount.text, "950")
        }

        // The form gives the expense an identity, so the save does not wait for the server
        @Test
        func creatingAnExpenseGeneratesItsIdentityAndDate() async {
            let now = Date(timeIntervalSince1970: 1_751_000_000)
            let created = Expense(
                amount: 13,
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

            await store.send(.name(.binding(.set(\.text, "  Phone Plan  ")))) {
                $0.name.text = "  Phone Plan  "
            }
            await store.send(.amount(.binding(.set(\.text, "13")))) {
                $0.amount.text = "13"
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

            await store.send(.amount(.binding(.set(\.text, "1,000")))) {
                $0.amount.text = "1,000"
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

            await store.send(.amount(.binding(.set(\.text, "12")))) {
                $0.amount.text = "12"
            }
            await store.send(.name(.binding(.set(\.text, "   ")))) {
                $0.name.text = "   "
            }
            await store.send(.saveButtonTapped)
        }

        @Test
        func everyFormStartsOnTheName() {
            let new = ExpenseForm.State()
            expectNoDifference(new.step, .name)
            expectNoDifference(new.focus, .name)

            let existing = ExpenseForm.State(expense: .rent)
            expectNoDifference(existing.step, .name)
            expectNoDifference(existing.focus, .name)
        }

        @Test
        func theNextButtonMovesToTheAmountOnlyWithAValidName() async {
            let store = TestStore(initialState: ExpenseForm.State()) {
                ExpenseForm()
            }

            await store.send(.nextButtonTapped)
            await store.send(
                .name(.binding(.set(\.text, String(repeating: "a", count: ExpenseName.maximumLength + 1))))
            ) {
                $0.name.text = String(repeating: "a", count: ExpenseName.maximumLength + 1)
            }
            await store.send(.nextButtonTapped)
            await store.send(.name(.binding(.set(\.text, "Netflix")))) {
                $0.name.text = "Netflix"
            }
            await store.send(.nextButtonTapped) {
                $0.focus = .amount
                $0.step = .amount
            }
            await store.send(.nextButtonTapped)
        }

        @Test
        func submittingTheNameMovesToTheAmount() async {
            let store = TestStore(initialState: ExpenseForm.State(expense: .gym)) {
                ExpenseForm()
            }

            await store.send(.nameFieldSubmitted) {
                $0.focus = .amount
                $0.step = .amount
            }
        }

        @Test
        func theBackButtonReturnsToTheName() async {
            let store = TestStore(initialState: ExpenseForm.State(expense: .gym)) {
                ExpenseForm()
            }

            await store.send(.backButtonTapped)
            await store.send(.nextButtonTapped) {
                $0.focus = .amount
                $0.step = .amount
            }
            await store.send(.backButtonTapped) {
                $0.focus = .name
                $0.step = .name
            }
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

        @Test
        func dismissingWithChangesClosesTheForm() async {
            await confirmation("Dismisses the form") { dismissesForm in
                let store = TestStore(initialState: ExpenseForm.State(expense: .rent)) {
                    ExpenseForm()
                } withDependencies: {
                    $0.dismiss = DismissEffect { dismissesForm() }
                }

                await store.send(.name(.binding(.set(\.text, "Office")))) {
                    $0.name.text = "Office"
                }
                await store.send(.dismissButtonTapped)
                await store.finish()
            }
        }
    }
}
