//
//  ExpenseDetail.swift
//  Overhead
//
//  Created by Lorenzo Mazzarotto on 24/07/26.
//

import ComposableArchitecture
import Foundation

@Reducer
struct ExpenseDetail {
    @Reducer
    enum Destination {
        case alert(AlertState<ExpenseDetail.Alert>)
        case editExpense(ExpenseForm)
    }

    enum Alert: Equatable {
        case confirmDeletion
    }

    @ObservableState
    struct State: Equatable {
        @SharedReader(.currency) var currency
        @Presents var destination: Destination.State?
        @SharedReader var expense: Expense
        @SharedReader(.hidesAmounts) var hidesAmounts

        var isPresenting: Bool { destination != nil }
    }

    enum Action {
        case delegate(Delegate)
        case deleteButtonTapped
        case destination(PresentationAction<Destination.Action>)
        case editButtonTapped

        @CasePathable
        enum Delegate {
            case didDelete(Expense.ID)
            case didUpdate(Expense)
        }
    }

    @Dependency(\.hapticsClient) var hapticsClient

    var body: some Reducer<State, Action> {
        Reduce { state, action in
            switch action {
            case .delegate:
                return .none

            case .deleteButtonTapped:
                state.destination = .alert(.confirmDeletion)
                return .none

            case .destination(.presented(.alert(.confirmDeletion))):
                return .send(.delegate(.didDelete(state.expense.id)))

            case .destination(.presented(.editExpense(.delegate(.didSubmit(let expense))))):
                state.destination = nil
                return .merge(
                    .run { _ in await hapticsClient.success() },
                    .send(.delegate(.didUpdate(expense)))
                )

            case .destination:
                return .none

            case .editButtonTapped:
                state.destination = .editExpense(ExpenseForm.State(expense: state.expense))
                return .none
            }
        }
        .ifLet(\.$destination, action: \.destination)
    }
}

extension ExpenseDetail.Destination.State: Equatable {}

extension AlertState where Action == ExpenseDetail.Alert {
    static let confirmDeletion = AlertState {
        TextState("Delete Expense")
    } actions: {
        ButtonState(role: .destructive, action: .confirmDeletion) {
            TextState("Delete")
        }
        ButtonState(role: .cancel) {
            TextState("Cancel")
        }
    } message: {
        TextState("Are you sure you want to delete this expense?")
    }
}
