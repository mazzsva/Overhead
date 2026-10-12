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
    enum Dialog: Equatable {
        case confirmDiscard
    }

    enum Field: Hashable {
        case name
    }

    @ObservableState
    struct State: Equatable {
        var amountText: String
        var billingCycle: BillingCycle
        @Presents var confirmationDialog: ConfirmationDialogState<ExpenseForm.Dialog>?
        @SharedReader(.currency) var currency
        let expense: Expense?
        var focus: Field?
        var isActive: Bool
        let locale: Locale
        var name: String

        init(expense: Expense? = nil) {
            @Dependency(\.locale) var locale
            amountText = expense?.amount.text(locale: locale) ?? ""
            billingCycle = expense?.billingCycle ?? .monthly
            self.expense = expense
            focus = expense == nil ? .name : nil
            isActive = expense?.isActive ?? true
            self.locale = locale
            name = expense?.name ?? ""
        }

        var amount: Amount? {
            amountInput.amount
        }

        var amountInput: AmountInput {
            AmountInput(text: amountText, locale: locale)
        }

        var hasChanges: Bool {
            amount != expense?.amount
                || amountInput.isInvalid
                || billingCycle != (expense?.billingCycle ?? .monthly)
                || isActive != (expense?.isActive ?? true)
                || name.trimmingCharacters(in: .whitespacesAndNewlines) != (expense?.name ?? "")
        }

        var isCreating: Bool {
            expense == nil
        }

        var isSubmittable: Bool {
            let name = name.trimmingCharacters(in: .whitespacesAndNewlines)
            return amount != nil && !name.isEmpty && name.utf16.count <= Expense.maximumNameLength
        }
    }

    enum Action: BindableAction {
        case binding(BindingAction<State>)
        case confirmationDialog(PresentationAction<Dialog>)
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

            case .confirmationDialog(.presented(.confirmDiscard)):
                return .run { _ in await dismiss() }

            case .confirmationDialog:
                return .none

            case .delegate:
                return .none

            case .dismissButtonTapped:
                guard state.hasChanges else { return .run { _ in await dismiss() } }
                state.confirmationDialog = .discardChanges(.confirmDiscard)
                return .none

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
        .ifLet(\.$confirmationDialog, action: \.confirmationDialog)
    }
}
