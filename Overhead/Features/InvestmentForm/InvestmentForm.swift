//
//  InvestmentForm.swift
//  Overhead
//
//  Created by Lorenzo Mazzarotto on 04/10/26.
//

import ComposableArchitecture
import Foundation

@Reducer
struct InvestmentForm {
    enum Alert: Equatable {
        case confirmDiscard
        case confirmRemoval
    }

    enum Field: Hashable {
        case investment
    }

    static let shares = [10, 15, 20]

    @ObservableState
    struct State: Equatable {
        @Presents var alert: AlertState<InvestmentForm.Alert>?
        var focus: Field?
        var income: Decimal
        let initialInvestmentText: String
        var investmentText: String
        let isEditing: Bool
        let locale: Locale

        init(income: Decimal, investment: Decimal?) {
            @Dependency(\.locale) var locale
            let investmentText = investment?.amountText(locale: locale) ?? ""
            focus = investment == nil ? .investment : nil
            self.income = income
            initialInvestmentText = investmentText
            self.investmentText = investmentText
            isEditing = investment != nil
            self.locale = locale
        }

        var exceedsIncome: Bool {
            guard let investment else { return false }
            return investment > income
        }

        var hasChanges: Bool {
            investmentText != initialInvestmentText
        }

        var investment: Decimal? {
            Decimal(amountText: investmentText, locale: locale)
        }

        var isInvestmentInvalid: Bool {
            !investmentText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && investment == nil
        }

        var isSubmittable: Bool {
            investment != nil && !exceedsIncome
        }

        var share: Decimal? {
            guard isSubmittable, let investment else { return nil }
            return investment / income
        }
    }

    enum Action: BindableAction {
        case alert(PresentationAction<Alert>)
        case binding(BindingAction<State>)
        case delegate(Delegate)
        case dismissButtonTapped
        case removeButtonTapped
        case saveButtonTapped
        case shareButtonTapped(Int)

        @CasePathable
        enum Delegate {
            case didRemove
            case didSubmit(Decimal)
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
                state.alert = .confirmRemoval
                return .none

            case .saveButtonTapped:
                guard state.isSubmittable, let investment = state.investment else { return .none }
                return .send(.delegate(.didSubmit(investment)))

            case .shareButtonTapped(let percent):
                let investment = (state.income * Decimal(percent) / 100).rounded(scale: 2)
                guard investment > 0 else { return .none }
                state.investmentText = investment.amountText(locale: state.locale)
                return .none
            }
        }
        .ifLet(\.$alert, action: \.alert)
    }
}

extension AlertState where Action == InvestmentForm.Alert {
    static let confirmRemoval = AlertState {
        TextState("Remove Investments")
    } actions: {
        ButtonState(role: .destructive, action: .confirmRemoval) {
            TextState("Remove")
        }
        ButtonState(role: .cancel) {
            TextState("Cancel")
        }
    } message: {
        TextState("Your investments will be removed. Your income and expenses will stay.")
    }
}
