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
    @Reducer
    enum Destination {
        case incomeForm(IncomeForm)
        case investmentForm(InvestmentForm)
    }

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

    enum BudgetChange: Hashable {
        case removeIncome
        case removeInvestments
        case saveIncome
        case saveInvestments
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
        var budgetStatus = BudgetStatus.loading
        @Presents var destination: Destination.State?
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
            destination != nil
        }

        var monthlyTotal: Decimal? {
            expenses.map { $0.filter(\.isActive).reduce(0) { $0 + $1.monthlyAmount }.rounded(scale: 2) }
        }
    }

    enum Action {
        case addIncomeButtonTapped
        case budgetStreamFailed
        case budgetUpdated(BudgetSnapshot)
        case delegate(Delegate)
        case destination(PresentationAction<Destination.Action>)
        case expensesRowTapped
        case incomeRowTapped
        case investmentsRowTapped
        case task

        @CasePathable
        enum Delegate {
            case didFailToChangeBudget(BudgetChange)
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
                guard state.destination == nil else { return .none }
                state.destination = .incomeForm(IncomeForm.State(budget: state.budget))
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
                let budget = snapshot.budget
                state.budgetStatus = .loaded(budget)
                switch state.destination {
                case .incomeForm:
                    state.destination?.modify(\.incomeForm) { $0.investment = budget?.investment }
                case .investmentForm:
                    guard let budget else {
                        state.destination = nil
                        return .none
                    }
                    state.destination?.modify(\.investmentForm) { $0.income = budget.income }
                case nil:
                    break
                }
                return .none

            case .delegate:
                return .none

            case .destination(.presented(.incomeForm(.delegate(.didRemove)))):
                state.destination = nil
                let uid = state.user.uid
                return .merge(
                    .run { _ in await hapticsClient.warning() },
                    changeBudget(.removeIncome) { try await budgetClient.delete(uid: uid) }
                )

            case .destination(.presented(.incomeForm(.delegate(.didSubmit(let income))))):
                return saveIncome(income, removingInvestment: false, state: &state)

            case .destination(.presented(.incomeForm(.delegate(.didSubmitRemovingInvestment(let income))))):
                return saveIncome(income, removingInvestment: true, state: &state)

            case .destination(.presented(.investmentForm(.delegate(.didRemove)))):
                state.destination = nil
                let uid = state.user.uid
                return .merge(
                    .run { _ in await hapticsClient.warning() },
                    changeBudget(.removeInvestments) { try await budgetClient.removeInvestment(uid: uid) }
                )

            case .destination(.presented(.investmentForm(.delegate(.didSubmit(let investment))))):
                state.destination = nil
                let uid = state.user.uid
                return .merge(
                    .run { _ in await hapticsClient.success() },
                    changeBudget(.saveInvestments) {
                        try await budgetClient.saveInvestment(investment: investment, uid: uid)
                    }
                )

            case .destination:
                return .none

            case .expensesRowTapped:
                return .send(.delegate(.didSelectExpenses))

            case .investmentsRowTapped:
                guard state.destination == nil, let budget = state.budget else { return .none }
                state.destination = .investmentForm(
                    InvestmentForm.State(income: budget.income, investment: budget.investment)
                )
                return .none

            case .task:
                return subscribeToBudget(uid: state.user.uid)
            }
        }
        .ifLet(\.$destination, action: \.destination)
    }

    private func changeBudget(
        _ change: BudgetChange,
        operation: @escaping @Sendable () async throws -> Void
    ) -> Effect<Action> {
        .run { _ in
            try await operation()
        } catch: { error, send in
            logger.error(
                "Changing the budget failed (\(String(describing: change), privacy: .public)): \(error, privacy: .public)"
            )
            await send(.delegate(.didFailToChangeBudget(change)))
        }
    }

    private func saveIncome(_ income: Decimal, removingInvestment: Bool, state: inout State) -> Effect<Action> {
        state.destination = nil
        let uid = state.user.uid
        return .merge(
            .run { _ in await hapticsClient.success() },
            changeBudget(.saveIncome) {
                try await budgetClient.saveIncome(income: income, removingInvestment: removingInvestment, uid: uid)
            }
        )
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

extension Overview.Destination.State: Equatable {}

private let logger = Logger(category: "Overview")
