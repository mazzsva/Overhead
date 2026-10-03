//
//  ExpenseForm.swift
//  Overhead
//
//  Created by Lorenzo Mazzarotto on 20/07/26.
//

import ComposableArchitecture
import Foundation
import RegexBuilder

@Reducer
struct ExpenseForm {
    @ObservableState
    struct State: Equatable {
        var amountText: String
        var billingCycle: BillingCycle
        let expense: Expense?
        var isActive: Bool
        let locale: Locale
        var name: String

        init(expense: Expense? = nil) {
            @Dependency(\.locale) var locale
            amountText =
                expense?.amount
                .formatted(
                    .number
                        .grouping(.never)
                        .locale(locale)
                        .precision(.fractionLength(2))
                ) ?? ""
            billingCycle = expense?.billingCycle ?? .monthly
            self.expense = expense
            isActive = expense?.isActive ?? true
            self.locale = locale
            name = expense?.name ?? ""
        }

        var amount: Decimal? {
            let text = amountText.trimmingCharacters(in: .whitespacesAndNewlines)
            let number = Regex { Capture { Decimal.FormatStyle(locale: locale) } }
            guard
                let amount = text.wholeMatch(of: number)?.output.1,
                amount > 0,
                amount.cents != nil
            else { return nil }
            return amount
        }

        var isCreating: Bool {
            expense == nil
        }

        var isSubmittable: Bool {
            amount != nil && !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
    }

    enum Action: BindableAction {
        case binding(BindingAction<State>)
        case delegate(Delegate)
        case dismissButtonTapped
        case saveButtonTapped

        @CasePathable
        enum Delegate {
            case didSubmit(Expense)
        }
    }

    @Dependency(\.date.now) var now
    @Dependency(\.dismiss) var dismiss
    @Dependency(\.uuid) var uuid

    var body: some Reducer<State, Action> {
        BindingReducer()
        Reduce { state, action in
            switch action {
            case .binding:
                return .none

            case .delegate:
                return .none

            case .dismissButtonTapped:
                return .run { _ in await dismiss() }

            case .saveButtonTapped:
                guard state.isSubmittable, let amount = state.amount else { return .none }
                let original = state.expense
                let expense = Expense(
                    amount: amount,
                    billingCycle: state.billingCycle,
                    createdAt: original?.createdAt ?? now,
                    id: original?.id ?? uuid(),
                    isActive: state.isActive,
                    name: state.name.trimmingCharacters(in: .whitespacesAndNewlines)
                )
                return .send(.delegate(.didSubmit(expense)))
            }
        }
    }
}
