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
    }

    enum Field: Hashable {
        case investment
    }

    struct ShareOption: Equatable, Identifiable {
        let amount: Amount?
        let percent: Int

        var id: Int { percent }
    }

    static let shares = [10, 15, 20]

    @ObservableState
    struct State: Equatable {
        @Presents var destination: Destination.State?
        var focus: Field? = .investment
        var investment: AmountField.State

        init(income: Amount, investment: Amount?) {
            self.investment = AmountField.State(investment, limit: income)
        }

        var exceedsIncome: Bool {
            guard case .overLimit = investment.input else { return false }
            return true
        }

        var income: Amount {
            get { investment.limit }
            set { investment.limit = newValue }
        }

        var isEditing: Bool {
            investment.initial != nil
        }

        var isSubmittable: Bool {
            investment.value != nil
        }

        var selectedSharePercent: Int? {
            guard let investment = investment.value else { return nil }
            return shareOptions.first { $0.amount == investment }?.percent
        }

        var share: Decimal? {
            guard let investment = investment.value else { return nil }
            return Decimal(investment.value) / Decimal(income.value)
        }

        var shareOptions: [ShareOption] {
            InvestmentForm.shares.map {
                ShareOption(amount: Amount(value: (income.value * $0 + 50) / 100), percent: $0)
            }
        }
    }

    enum Action: BindableAction {
        case binding(BindingAction<State>)
        case delegate(Delegate)
        case destination(PresentationAction<Destination.Action>)
        case dismissButtonTapped
        case investment(AmountField.Action)
        case removeButtonTapped
        case saveButtonTapped
        case shareButtonTapped(Int)

        @CasePathable
        enum Delegate {
            case didRemove
            case didSubmit(Amount)
        }
    }

    @Dependency(\.dismiss) var dismiss

    var body: some Reducer<State, Action> {
        BindingReducer()
        Scope(state: \.investment, action: \.investment) {
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

            case .destination:
                return .none

            case .dismissButtonTapped:
                return .run { _ in await dismiss() }

            case .investment:
                return .none

            case .removeButtonTapped:
                guard state.isEditing else { return .none }
                state.destination = .alert(.confirmRemoval)
                return .none

            case .saveButtonTapped:
                guard let investment = state.investment.value else { return .none }
                return .send(.delegate(.didSubmit(investment)))

            case .shareButtonTapped(let percent):
                guard let amount = state.shareOptions.first(where: { $0.percent == percent })?.amount else {
                    return .none
                }
                state.investment.fill(amount)
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
