//
//  Overview.swift
//  Overhead
//
//  Created by Lorenzo Mazzarotto on 04/10/26.
//

import ComposableArchitecture
import Foundation
import os

@Reducer
struct Overview {
    @CasePathable
    enum BudgetStatus: Equatable {
        case loaded(Budget?)
        case loading
    }

    @ObservableState
    struct State: Equatable {
        var budgetStatus = BudgetStatus.loading
        @SharedReader var expenses: IdentifiedArrayOf<Expense>?
        let user: User

        var activeExpenseCount: Int {
            (expenses ?? []).count(where: \.isActive)
        }

        var budget: Budget? {
            budgetStatus[case: \.loaded] ?? nil
        }

        var expensesShare: Decimal? {
            shareOfIncome(monthlyTotal)
        }

        var investmentShare: Decimal? {
            budget?.investment.flatMap(shareOfIncome)
        }

        var leftToSpend: Decimal? {
            budget.map { $0.income - monthlyTotal - ($0.investment ?? 0) }
        }

        var leftToSpendShare: Decimal? {
            leftToSpend.flatMap(shareOfIncome)
        }

        var monthlyTotal: Decimal {
            (expenses ?? []).filter(\.isActive).reduce(0) { $0 + $1.monthlyAmount }
        }

        private func shareOfIncome(_ amount: Decimal) -> Decimal? {
            budget.map { amount / $0.income }
        }
    }

    enum Action {
        case budgetRetryTimerElapsed
        case budgetStreamFailed
        case budgetUpdated(Budget?)
        case delegate(Delegate)
        case expensesRowTapped
        case task

        @CasePathable
        enum Delegate {
            case didSelectExpenses
        }
    }

    enum CancelID {
        case budgetSubscription
    }

    @Dependency(\.budgetClient) var budgetClient
    @Dependency(\.continuousClock) var clock

    var body: some Reducer<State, Action> {
        Reduce { state, action in
            switch action {
            case .budgetRetryTimerElapsed:
                return subscribeToBudget(uid: state.user.uid)

            case .budgetStreamFailed:
                return
                    .run { send in
                        try await clock.sleep(for: .seconds(5))
                        await send(.budgetRetryTimerElapsed)
                    }
                    .cancellable(id: CancelID.budgetSubscription, cancelInFlight: true)

            case .budgetUpdated(let budget):
                state.budgetStatus = .loaded(budget)
                return .none

            case .delegate:
                return .none

            case .expensesRowTapped:
                return .send(.delegate(.didSelectExpenses))

            case .task:
                return subscribeToBudget(uid: state.user.uid)
            }
        }
    }

    private func subscribeToBudget(uid: String) -> Effect<Action> {
        .run { send in
            do {
                let snapshots = await budgetClient.budget(uid: uid)
                for try await budget in snapshots {
                    await send(.budgetUpdated(budget))
                }
            } catch {
                logger.error("Budget stream failed: \(error, privacy: .public)")
                await send(.budgetStreamFailed)
            }
        }
        .cancellable(id: CancelID.budgetSubscription, cancelInFlight: true)
    }
}

private let logger = Logger(category: "Overview")
