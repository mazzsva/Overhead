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
        case offline
    }

    @ObservableState
    struct State: Equatable {
        @Presents var budgetForm: BudgetForm.State?
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

        var isPresenting: Bool {
            budgetForm != nil
        }

        var monthlyTotal: Decimal? {
            expenses.map { $0.filter(\.isActive).reduce(0) { $0 + $1.monthlyAmount }.rounded(scale: 2) }
        }
    }

    enum Action {
        case addIncomeButtonTapped
        case budgetForm(PresentationAction<BudgetForm.Action>)
        case budgetStreamFailed
        case budgetUpdated(BudgetSnapshot)
        case delegate(Delegate)
        case expensesRowTapped
        case incomeRowTapped
        case investmentsRowTapped
        case task

        @CasePathable
        enum Delegate {
            case didFailToSaveBudget
            case didSelectExpenses
        }
    }

    enum CancelID {
        case budgetSubscription
    }

    @Dependency(\.budgetClient) var budgetClient
    @Dependency(\.continuousClock) var clock
    @Dependency(\.hapticsClient) var hapticsClient

    var body: some Reducer<State, Action> {
        Reduce { state, action in
            switch action {
            case .addIncomeButtonTapped, .incomeRowTapped:
                state.budgetForm = BudgetForm.State(budget: state.budget, focus: .income)
                return .none

            case .budgetForm(.presented(.delegate(.didSubmit(let budget)))):
                state.budgetForm = nil
                return .merge(
                    .run { _ in await hapticsClient.success() },
                    save(budget, uid: state.user.uid)
                )

            case .budgetForm:
                return .none

            case .budgetStreamFailed:
                guard state.budgetStatus == .loading else { return .none }
                state.budgetStatus = .failed
                return .none

            case .budgetUpdated(let snapshot):
                guard
                    snapshot.budget != nil || !snapshot.isFromCache || state.budgetStatus.is(\.loaded)
                else {
                    state.budgetStatus = .offline
                    return .none
                }
                state.budgetStatus = .loaded(snapshot.budget)
                return .none

            case .delegate:
                return .none

            case .expensesRowTapped:
                return .send(.delegate(.didSelectExpenses))

            case .investmentsRowTapped:
                state.budgetForm = BudgetForm.State(budget: state.budget, focus: .investment)
                return .none

            case .task:
                return subscribeToBudget(uid: state.user.uid)
            }
        }
        .ifLet(\.$budgetForm, action: \.budgetForm) {
            BudgetForm()
        }
    }

    private func save(_ budget: Budget, uid: String) -> Effect<Action> {
        .run { _ in
            try await budgetClient.save(budget: budget, uid: uid)
        } catch: { error, send in
            logger.error("Saving the budget failed: \(error, privacy: .public)")
            await send(.delegate(.didFailToSaveBudget))
        }
    }

    private func subscribeToBudget(uid: String) -> Effect<Action> {
        .run { send in
            while true {
                do {
                    let snapshots = await budgetClient.budget(uid: uid)
                    for try await snapshot in snapshots {
                        await send(.budgetUpdated(snapshot))
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
