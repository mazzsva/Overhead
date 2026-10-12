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
        case confirmRemoval
    }

    @Reducer
    enum Destination {
        case alert(AlertState<InvestmentForm.Alert>)
        case confirmationDialog(ConfirmationDialogState<InvestmentForm.Dialog>)
    }

    enum Dialog: Equatable {
        case confirmDiscard
    }

    enum Field: Hashable {
        case investment
    }

    struct ShareOption: Equatable, Identifiable {
        let amount: Decimal
        let percent: Int

        var id: Int { percent }
    }

    static let shares = [10, 15, 20]

    @ObservableState
    struct State: Equatable {
        @SharedReader(.currency) var currency
        @Presents var destination: Destination.State?
        var focus: Field? = .investment
        var income: Decimal
        let initialInvestment: Decimal?
        var investmentText: String
        let locale: Locale

        init(income: Decimal, investment: Decimal?) {
            @Dependency(\.locale) var locale
            self.income = income
            initialInvestment = investment
            investmentText = investment?.amountText(locale: locale) ?? ""
            self.locale = locale
        }

        var exceedsIncome: Bool {
            guard let investment else { return false }
            return investment > income
        }

        var hasChanges: Bool {
            investment != initialInvestment || isInvestmentInvalid
        }

        var investment: Decimal? {
            Decimal(amountText: investmentText, locale: locale)
        }

        var isEditing: Bool {
            initialInvestment != nil
        }

        var isInvestmentInvalid: Bool {
            !investmentText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && investment == nil
        }

        var isInvestmentRefused: Bool {
            exceedsIncome || (isInvestmentInvalid && Decimal(amountText: investmentText + "1", locale: locale) == nil)
        }

        var isSubmittable: Bool {
            investment != nil && !exceedsIncome
        }

        var selectedSharePercent: Int? {
            guard let investment else { return nil }
            return shareOptions.first { $0.amount == investment }?.percent
        }

        var share: Decimal? {
            guard isSubmittable, let investment else { return nil }
            return investment / income
        }

        var shareOptions: [ShareOption] {
            InvestmentForm.shares.map {
                ShareOption(amount: (income * Decimal($0) / 100).rounded(scale: 2), percent: $0)
            }
        }
    }

    enum Action: BindableAction {
        case binding(BindingAction<State>)
        case delegate(Delegate)
        case destination(PresentationAction<Destination.Action>)
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
            case .binding:
                return .none

            case .delegate:
                return .none

            case .destination(.presented(.alert(.confirmRemoval))):
                return .send(.delegate(.didRemove))

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
                state.destination = .alert(.confirmRemoval)
                return .none

            case .saveButtonTapped:
                guard state.isSubmittable, let investment = state.investment else { return .none }
                return .send(.delegate(.didSubmit(investment)))

            case .shareButtonTapped(let percent):
                guard let option = state.shareOptions.first(where: { $0.percent == percent }), option.amount > 0
                else { return .none }
                state.investmentText = option.amount.amountText(locale: state.locale)
                return .none
            }
        }
        .ifLet(\.$destination, action: \.destination)
    }
}

extension InvestmentForm.Destination.State: Equatable {}

extension AlertState where Action == InvestmentForm.Alert {
    static let confirmRemoval = AlertState {
        TextState("Remove Savings")
    } actions: {
        ButtonState(role: .destructive, action: .confirmRemoval) {
            TextState("Remove")
        }
        ButtonState(role: .cancel) {
            TextState("Cancel")
        }
    } message: {
        TextState("Your savings will be removed. Your income and expenses will stay.")
    }
}
