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
    struct Breakdown: Equatable {
        struct Line: Equatable {
            let amount: Decimal
            let share: Decimal
        }

        struct Segment: Equatable, Identifiable {
            let amount: Decimal
            let part: BudgetPart

            var id: BudgetPart { part }
        }

        let expenses: Line
        let income: Decimal
        let investments: Line?
        let leftToSpend: Line

        init(budget: Budget, monthlyTotal: Decimal) {
            let expenses = Line(amount: -monthlyTotal, share: (monthlyTotal / budget.income).rounded(scale: 2))
            let investments = budget.investment.map {
                Line(amount: -$0, share: ($0 / budget.income).rounded(scale: 2))
            }
            self.expenses = expenses
            income = budget.income
            self.investments = investments
            leftToSpend = Line(
                amount: budget.income + expenses.amount + (investments?.amount ?? 0),
                share: 1 - expenses.share - (investments?.share ?? 0)
            )
        }

        var chartSegments: [Segment] {
            [
                Segment(amount: -expenses.amount, part: .expenses),
                Segment(amount: -(investments?.amount ?? 0), part: .investments),
                Segment(amount: leftToSpend.amount, part: .leftToSpend),
            ]
            .filter { $0.amount > 0 }
        }

        var chartUpperBound: Decimal {
            max(income, -expenses.amount - (investments?.amount ?? 0))
        }

        var isOverBudget: Bool {
            leftToSpend.amount < 0
        }
    }

    enum BudgetPart: Hashable {
        case expenses
        case investments
        case leftToSpend
    }

    @CasePathable
    @dynamicMemberLookup
    enum BudgetStatus: Equatable {
        case failed
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

        var breakdown: Breakdown? {
            guard let budget, let monthlyTotal else { return nil }
            return Breakdown(budget: budget, monthlyTotal: monthlyTotal)
        }

        var budget: Budget? {
            budgetStatus.loaded ?? nil
        }

        var monthlyTotal: Decimal? {
            expenses.map { $0.filter(\.isActive).reduce(0) { $0 + $1.monthlyAmount }.rounded(scale: 2) }
        }
    }

    enum Action {
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
            case .budgetStreamFailed:
                guard state.budgetStatus == .loading else { return .none }
                state.budgetStatus = .failed
                return .none

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
            while true {
                do {
                    let snapshots = await budgetClient.budget(uid: uid)
                    for try await budget in snapshots {
                        await send(.budgetUpdated(budget))
                    }
                    return
                } catch {
                    logger.error("Budget stream failed: \(error, privacy: .public)")
                    await send(.budgetStreamFailed)
                }
                try await clock.sleep(for: .seconds(5))
            }
        }
        .cancellable(id: CancelID.budgetSubscription, cancelInFlight: true)
    }
}

private let logger = Logger(category: "Overview")
