//
//  BudgetForm.swift
//  Overhead
//
//  Created by Lorenzo Mazzarotto on 04/10/26.
//

import ComposableArchitecture
import Foundation

@Reducer
struct BudgetForm {
    enum Field: Hashable {
        case income
        case investment
    }

    @ObservableState
    struct State: Equatable {
        var focus: Field?
        var incomeText: String
        var investmentText: String
        let locale: Locale

        init(budget: Budget?, focus: Field) {
            @Dependency(\.locale) var locale
            self.focus = focus
            incomeText = budget?.income.amountText(locale: locale) ?? ""
            investmentText = budget?.investment?.amountText(locale: locale) ?? ""
            self.locale = locale
        }

        var budget: Budget? {
            guard let income = Decimal(amountText: incomeText, locale: locale) else { return nil }
            guard !investmentText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                return Budget(income: income, investment: nil)
            }
            guard
                let investment = Decimal(amountText: investmentText, locale: locale),
                investment <= income
            else { return nil }
            return Budget(income: income, investment: investment)
        }

        var investmentExceedsIncome: Bool {
            guard
                let income = Decimal(amountText: incomeText, locale: locale),
                let investment = Decimal(amountText: investmentText, locale: locale)
            else { return false }
            return investment > income
        }

        var investmentShare: Decimal? {
            guard let budget, let investment = budget.investment else { return nil }
            return investment / budget.income
        }

        var isIncomeValid: Bool {
            Decimal(amountText: incomeText, locale: locale) != nil
        }
    }

    enum Action: BindableAction {
        case binding(BindingAction<State>)
        case delegate(Delegate)
        case dismissButtonTapped
        case investmentShareButtonTapped(Int)
        case saveButtonTapped

        @CasePathable
        enum Delegate {
            case didSubmit(Budget)
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

            case .dismissButtonTapped:
                return .run { _ in await dismiss() }

            case .investmentShareButtonTapped(let percent):
                guard let income = Decimal(amountText: state.incomeText, locale: state.locale) else { return .none }
                var investment = income * Decimal(percent) / 100
                var rounded = Decimal()
                NSDecimalRound(&rounded, &investment, 2, .plain)
                state.investmentText = rounded.amountText(locale: state.locale)
                return .none

            case .saveButtonTapped:
                guard let budget = state.budget else { return .none }
                return .send(.delegate(.didSubmit(budget)))
            }
        }
    }
}
