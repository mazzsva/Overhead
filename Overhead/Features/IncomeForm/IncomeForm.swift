//
//  IncomeForm.swift
//  Overhead
//
//  Created by Lorenzo Mazzarotto on 04/10/26.
//

import ComposableArchitecture
import Foundation

@Reducer
struct IncomeForm {
    enum Alert: Equatable {
        case confirmRemoval
        case confirmRemovingInvestment
    }

    @Reducer
    enum Destination {
        case alert(AlertState<IncomeForm.Alert>)
        case confirmationDialog(ConfirmationDialogState<IncomeForm.Dialog>)
    }

    enum Dialog: Equatable {
        case confirmDiscard
    }

    enum Field: Hashable {
        case income
    }

    @ObservableState
    struct State: Equatable {
        @SharedReader(.currency) var currency
        @Presents var destination: Destination.State?
        var focus: Field? = .income
        var incomeText: String
        let initialIncome: Amount?
        var investment: Amount?
        let locale: Locale

        init(budget: Budget?) {
            @Dependency(\.locale) var locale
            incomeText = budget?.income.text(locale: locale) ?? ""
            initialIncome = budget?.income
            investment = budget?.investment
            self.locale = locale
        }

        var hasChanges: Bool {
            income != initialIncome || incomeInput.isInvalid
        }

        var income: Amount? {
            incomeInput.amount
        }

        var incomeInput: AmountInput {
            AmountInput(text: incomeText, locale: locale)
        }

        var isBelowInvestment: Bool {
            guard let income, let investment else { return false }
            return income < investment
        }

        var isEditing: Bool {
            initialIncome != nil
        }

        var isIncomeRefused: Bool {
            incomeInput == .refused
        }
    }

    enum Action: BindableAction {
        case binding(BindingAction<State>)
        case delegate(Delegate)
        case destination(PresentationAction<Destination.Action>)
        case dismissButtonTapped
        case removeButtonTapped
        case saveButtonTapped

        @CasePathable
        enum Delegate {
            case didRemove
            case didSubmit(Amount)
            case didSubmitRemovingInvestment(Amount)
        }
    }

    @Dependency(\.dismiss) var dismiss

    var body: some Reducer<State, Action> {
        BindingReducer()
        Reduce { state, action in
            switch action {
            case .binding:
                return .none

            case .delegate:
                return .none

            case .destination(.presented(.alert(.confirmRemoval))):
                return .send(.delegate(.didRemove))

            case .destination(.presented(.alert(.confirmRemovingInvestment))):
                guard let income = state.income else { return .none }
                return .send(.delegate(.didSubmitRemovingInvestment(income)))

            case .destination(.presented(.confirmationDialog(.confirmDiscard))):
                return .run { _ in await dismiss() }

            case .destination:
                return .none

            case .dismissButtonTapped:
                guard state.hasChanges else { return .run { _ in await dismiss() } }
                state.destination = .confirmationDialog(.discardChanges(.confirmDiscard))
                return .none

            case .removeButtonTapped:
                guard state.isEditing else { return .none }
                state.destination = .alert(.confirmRemoval(removesInvestment: state.investment != nil))
                return .none

            case .saveButtonTapped:
                guard let income = state.income else { return .none }
                if let investment = state.investment, income < investment {
                    state.destination = .alert(
                        .confirmRemovingInvestment(investment, currency: state.currency, locale: state.locale)
                    )
                    return .none
                }
                return .send(.delegate(.didSubmit(income)))
            }
        }
        .ifLet(\.$destination, action: \.destination)
    }
}

extension IncomeForm.Destination.State: Equatable {}

extension AlertState where Action == IncomeForm.Alert {
    static func confirmRemoval(removesInvestment: Bool) -> Self {
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
            removesInvestment
                ? TextState("Your income and savings will be removed. Your expenses will stay.")
                : TextState("Your income will be removed. Your expenses will stay.")
        }
    }

    static func confirmRemovingInvestment(_ investment: Amount, currency: Currency, locale: Locale) -> Self {
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
            TextState(
                "Your savings of \(investment.value.formatted(.currency(currency).locale(locale))) are more than this income."
            )
        }
    }
}
