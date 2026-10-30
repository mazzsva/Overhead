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
    }

    enum Field: Hashable {
        case income
    }

    @ObservableState
    struct State: Equatable {
        @Presents var destination: Destination.State?
        var focus: Field? = .income
        var income: AmountField.State
        var investment: Amount?

        init(budget: Budget?) {
            income = AmountField.State(budget?.income)
            investment = budget?.investment
        }

        var isBelowInvestment: Bool {
            guard let income = income.value, let investment else { return false }
            return income < investment
        }

        var isEditing: Bool {
            income.initial != nil
        }

        var isSubmittable: Bool {
            income.value != nil
        }
    }

    enum Action: BindableAction {
        case binding(BindingAction<State>)
        case delegate(Delegate)
        case destination(PresentationAction<Destination.Action>)
        case dismissButtonTapped
        case income(AmountField.Action)
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
        Scope(state: \.income, action: \.income) {
            AmountField()
        }
        Reduce { state, action in
            switch action {
            case .binding:
                return .none

            case .delegate:
                return .none

            case .destination(.presented(.alert(.confirmRemoval))):
                return .send(.delegate(.didRemove))

            case .destination(.presented(.alert(.confirmRemovingInvestment))):
                guard let income = state.income.value else { return .none }
                return .send(.delegate(.didSubmitRemovingInvestment(income)))

            case .destination:
                return .none

            case .dismissButtonTapped:
                return .run { _ in await dismiss() }

            case .income:
                return .none

            case .removeButtonTapped:
                guard state.isEditing else { return .none }
                state.destination = .alert(.confirmRemoval(removesInvestment: state.investment != nil))
                return .none

            case .saveButtonTapped:
                guard let income = state.income.value else { return .none }
                if let investment = state.investment, income < investment {
                    state.destination = .alert(
                        .confirmRemovingInvestment(
                            investment, currency: state.income.currency, locale: state.income.locale)
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
