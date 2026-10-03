//
//  Expenses.swift
//  Overhead
//
//  Created by Lorenzo Mazzarotto on 24/07/26.
//

import ComposableArchitecture
import Foundation
import os

@Reducer
struct Expenses {
    @Reducer
    enum Destination {
        case createExpense(ExpenseForm)
    }

    @ObservableState
    struct State: Equatable {
        @SharedReader var defaultCurrencyCode: String?
        @Presents var destination: Destination.State?
        @Shared var expenses: IdentifiedArrayOf<Expense>?
        var path = StackState<ExpenseDetail.State>()
        let sessionOrigin: SessionOrigin
        let user: User

        init(user: User, sessionOrigin: SessionOrigin = .restored) {
            _defaultCurrencyCode = SharedReader(wrappedValue: nil, .defaultCurrencyCode(uid: user.uid))
            _expenses = Shared(value: nil)
            self.sessionOrigin = sessionOrigin
            self.user = user
        }

        var isEmpty: Bool { expenses?.isEmpty == true }

        var isFreshSignIn: Bool { sessionOrigin.is(\.freshSignIn) }

        var isLoadingFirstExpenses: Bool { expenses == nil }

        var isPresenting: Bool {
            destination != nil || path.contains { $0.isPresenting }
        }

        var listedExpenses: [SharedReader<Expense>] {
            guard let expenses = Shared($expenses) else { return [] }
            return Array(expenses).map { SharedReader($0) }
        }
    }

    enum Action {
        case delegate(Delegate)
        case destination(PresentationAction<Destination.Action>)
        case expensesRetryTimerElapsed
        case expensesStreamFailed
        case expensesUpdated([Expense])
        case newExpenseButtonTapped
        case path(StackActionOf<ExpenseDetail>)
        case task

        @CasePathable
        enum Delegate {
            case didFailToDelete
            case didFailToSave
        }
    }

    enum CancelID {
        case expensesSubscription
    }

    @Dependency(\.continuousClock) var clock
    @Dependency(\.expensesClient) var expensesClient
    @Dependency(\.hapticsClient) var hapticsClient

    var body: some Reducer<State, Action> {
        Reduce { state, action in
            switch action {
            case .delegate:
                return .none

            case .destination(.presented(.createExpense(.delegate(.didSubmit(let expense))))):
                state.destination = nil
                return .merge(
                    .run { _ in await hapticsClient.success() },
                    save(expense, uid: state.user.uid)
                )

            case .destination:
                return .none

            case .expensesRetryTimerElapsed:
                return subscribeToExpenses(state)

            case .expensesStreamFailed:
                let retry: Effect<Action> =
                    .run { send in
                        try await clock.sleep(for: .seconds(5))
                        await send(.expensesRetryTimerElapsed)
                    }
                    .cancellable(id: CancelID.expensesSubscription, cancelInFlight: true)
                guard state.expenses == nil else { return retry }
                state.$expenses.withLock { $0 = [] }
                return .merge(retry, celebrateFirstLoad(state))

            case .expensesUpdated(let expenses):
                let isFirstLoad = state.expenses == nil
                let expenses = IdentifiedArray(uniqueElements: expenses.sorted(by: Expense.listOrder))
                state.$expenses.withLock { $0 = expenses }
                for id in Array(state.path.ids) {
                    guard
                        let expenseID = state.path[id: id]?.expense.id,
                        expenses[id: expenseID] == nil
                    else { continue }
                    state.path.pop(from: id)
                }
                guard isFirstLoad else { return .none }
                return celebrateFirstLoad(state)

            case .newExpenseButtonTapped:
                state.destination = .createExpense(
                    ExpenseForm.State(defaultCurrencyCode: state.defaultCurrencyCode)
                )
                return .none

            case .path(.element(id: let id, action: .delegate(.didDelete(let expenseID)))):
                state.path.pop(from: id)
                return .merge(
                    .run { _ in await hapticsClient.warning() },
                    delete(expenseID, uid: state.user.uid)
                )

            case .path(.element(id: _, action: .delegate(.didUpdate(let expense)))):
                return save(expense, uid: state.user.uid)

            case .path:
                return .none

            case .task:
                return subscribeToExpenses(state)
            }
        }
        .ifLet(\.$destination, action: \.destination)
        .forEach(\.path, action: \.path) {
            ExpenseDetail()
        }
    }

    // The haptic welcomes the user into the app, so it plays even when the expenses fail to load
    private func celebrateFirstLoad(_ state: State) -> Effect<Action> {
        state.isFreshSignIn ? .run { _ in await hapticsClient.success() } : .none
    }

    private func delete(_ id: Expense.ID, uid: String) -> Effect<Action> {
        .run { _ in
            try await expensesClient.delete(id: id, uid: uid)
        } catch: { error, send in
            logger.error("Deleting expense \(id, privacy: .public) failed: \(error, privacy: .public)")
            await send(.delegate(.didFailToDelete))
        }
    }

    private func save(_ expense: Expense, uid: String) -> Effect<Action> {
        .run { _ in
            try await expensesClient.save(expense: expense, uid: uid)
        } catch: { error, send in
            logger.error("Saving expense \(expense.id, privacy: .public) failed: \(error, privacy: .public)")
            await send(.delegate(.didFailToSave))
        }
    }

    private func subscribeToExpenses(_ state: State) -> Effect<Action> {
        let uid = state.user.uid
        return
            .run { send in
                do {
                    let snapshots = await expensesClient.expenses(uid: uid)
                    for try await expenses in snapshots {
                        await send(.expensesUpdated(expenses))
                    }
                } catch {
                    logger.error("Expenses stream failed: \(error, privacy: .public)")
                    await send(.expensesStreamFailed)
                }
            }
            .cancellable(id: CancelID.expensesSubscription, cancelInFlight: true)
    }
}

extension Expenses.Destination.State: Equatable {}

private let logger = Logger(category: "Expenses")
