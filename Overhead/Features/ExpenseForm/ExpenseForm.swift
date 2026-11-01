//
//  ExpenseForm.swift
//  Overhead
//
//  Created by Lorenzo Mazzarotto on 20/07/26.
//

import ComposableArchitecture
import Foundation

@Reducer
struct ExpenseForm {
    enum Field: Hashable {
        case amount
        case name
    }

    @ObservableState
    struct State: Equatable {
        var amount: AmountField.State
        var billingCycle: BillingCycle
        let expense: Expense?
        var focus: Field?
        var name: NameField.State

        init(expense: Expense? = nil) {
            amount = AmountField.State(expense?.amount)
            billingCycle = expense?.billingCycle ?? .monthly
            self.expense = expense
            focus = .amount
            name = NameField.State(expense?.name)
        }

        var isActive: Bool {
            expense?.isActive ?? true
        }

        var isCreating: Bool {
            expense == nil
        }

        var isSubmittable: Bool {
            amount.value != nil && name.value != nil
        }
    }

    enum Action: BindableAction {
        case amount(AmountField.Action)
        case billingCycleButtonTapped(BillingCycle)
        case binding(BindingAction<State>)
        case delegate(Delegate)
        case dismissButtonTapped
        case name(NameField.Action)
        case nameFieldSubmitted
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
        Scope(state: \.amount, action: \.amount) {
            AmountField()
        }
        Scope(state: \.name, action: \.name) {
            NameField()
        }
        Reduce { state, action in
            switch action {
            case .amount:
                return .none

            case .billingCycleButtonTapped(let billingCycle):
                state.billingCycle = billingCycle
                return .none

            case .binding:
                return .none

            case .nameFieldSubmitted:
                state.focus = state.amount.value == nil ? .amount : nil
                return .none

            case .delegate:
                return .none

            case .dismissButtonTapped:
                return .run { _ in await dismiss() }

            case .name:
                return .none

            case .saveButtonTapped:
                guard let amount = state.amount.value, let name = state.name.value else { return .none }
                let original = state.expense
                let expense = Expense(
                    amount: amount,
                    billingCycle: state.billingCycle,
                    createdAt: original?.createdAt ?? now,
                    id: original?.id ?? uuid(),
                    isActive: state.isActive,
                    name: name
                )
                return .send(.delegate(.didSubmit(expense)))
            }
        }
    }
}
