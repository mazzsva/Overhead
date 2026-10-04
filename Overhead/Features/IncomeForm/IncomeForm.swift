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
        case confirmDiscard
        case confirmRemoval
        case confirmRemovingInvestment
    }

    enum Field: Hashable {
        case income
    }

    @ObservableState
    struct State: Equatable {
        @Presents var alert: AlertState<IncomeForm.Alert>?
        var focus: Field?
        var incomeText: String
        let initialIncomeText: String
        var investment: Decimal?
        let isEditing: Bool
        let locale: Locale

        init(budget: Budget?) {
            @Dependency(\.locale) var locale
            let incomeText = budget?.income.amountText(locale: locale) ?? ""
            focus = budget == nil ? .income : nil
            self.incomeText = incomeText
            initialIncomeText = incomeText
            investment = budget?.investment
            isEditing = budget != nil
            self.locale = locale
        }

        var hasChanges: Bool {
            incomeText != initialIncomeText
        }

        var income: Decimal? {
            Decimal(amountText: incomeText, locale: locale)
        }

        var isBelowInvestment: Bool {
            guard let income, let investment else { return false }
            return income < investment
        }

        var isIncomeInvalid: Bool {
            !incomeText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && income == nil
        }
    }

    enum Action: BindableAction {
        case alert(PresentationAction<Alert>)
        case binding(BindingAction<State>)
        case delegate(Delegate)
        case dismissButtonTapped
        case removeButtonTapped
        case saveButtonTapped

        @CasePathable
        enum Delegate {
            case didRemove
            case didSubmit(Decimal)
            case didSubmitRemovingInvestment(Decimal)
        }
    }

    @Dependency(\.dismiss) var dismiss

    var body: some Reducer<State, Action> {
        BindingReducer()
        Reduce { state, action in
            switch action {
            case .alert(.presented(.confirmDiscard)):
                return .run { _ in await dismiss() }

            case .alert(.presented(.confirmRemoval)):
                return .send(.delegate(.didRemove))

            case .alert(.presented(.confirmRemovingInvestment)):
                guard let income = state.income else { return .none }
                return .send(.delegate(.didSubmitRemovingInvestment(income)))

            case .alert:
                return .none

            case .binding:
                return .none

            case .delegate:
                return .none

            case .dismissButtonTapped:
                guard state.hasChanges else { return .run { _ in await dismiss() } }
                state.alert = .discardChanges(.confirmDiscard)
                return .none

            case .removeButtonTapped:
                guard state.isEditing else { return .none }
                state.alert = .confirmRemoval(removesInvestment: state.investment != nil)
                return .none

            case .saveButtonTapped:
                guard let income = state.income else { return .none }
                if let investment = state.investment, income < investment {
                    state.alert = .confirmRemovingInvestment(investment, locale: state.locale)
                    return .none
                }
                return .send(.delegate(.didSubmit(income)))
            }
        }
        .ifLet(\.$alert, action: \.alert)
    }
}

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
                ? TextState("Your income and investments will be removed. Your expenses will stay.")
                : TextState("Your income will be removed. Your expenses will stay.")
        }
    }

    static func confirmRemovingInvestment(_ investment: Decimal, locale: Locale) -> Self {
        AlertState {
            TextState("Remove Investments?")
        } actions: {
            ButtonState(role: .destructive, action: .confirmRemovingInvestment) {
                TextState("Remove Investments and Save")
            }
            ButtonState(role: .cancel) {
                TextState("Cancel")
            }
        } message: {
            TextState(
                "Your investments of \(investment.formatted(.dollars.locale(locale))) are more than this income."
            )
        }
    }
}
