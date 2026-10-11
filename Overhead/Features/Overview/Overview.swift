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
            let end: Double
            let part: BudgetPart
            let start: Double

            var id: BudgetPart { part }
        }

        enum ShareLabel: Equatable {
            case lessThanOnePercent
            case moreThanNinetyNinePercent
            case moreThanOneHundredPercent
            case percent(Decimal)
        }

        let annualExpenses: Decimal
        let budget: Budget
        let period: Period

        var available: Line {
            let amount = income - expenses.amount - (savings?.amount ?? 0)
            return Line(
                amount: isOverBudget ? min(amount, 0) : max(amount, 0),
                share: 1 - expenses.share - (savings?.share ?? 0)
            )
        }

        var availableShareLabel: ShareLabel {
            shareLabel(available, annual: annualIncome - annualCommitted)
        }

        var committed: Line {
            Line(
                amount: expenses.amount + (savings?.amount ?? 0),
                share: expenses.share + (savings?.share ?? 0)
            )
        }

        var committedShareLabel: ShareLabel {
            shareLabel(committed, annual: annualCommitted)
        }

        var expenses: Line {
            Line(
                amount: period.amount(annual: annualExpenses),
                share: (annualExpenses / annualIncome).rounded(scale: 2)
            )
        }

        var expensesShareLabel: ShareLabel {
            shareLabel(expenses, annual: annualExpenses)
        }

        var hasExpenses: Bool {
            annualExpenses > 0
        }

        var income: Decimal {
            period.amount(annual: annualIncome)
        }

        var incomeMark: Double? {
            guard isOverBudget else { return nil }
            return (annualIncome / annualCommitted).doubleValue
        }

        var isFullyCommitted: Bool {
            annualCommitted == annualIncome
        }

        var isOverBudget: Bool {
            annualCommitted > annualIncome
        }

        var savings: Line? {
            budget.investment.map {
                Line(amount: period.amount(annual: $0 * 12), share: ($0 * 12 / annualIncome).rounded(scale: 2))
            }
        }

        var savingsShareLabel: ShareLabel? {
            savings.map { shareLabel($0, annual: annualSavings) }
        }

        var segments: [Segment] {
            let total = max(annualIncome, annualCommitted)
            var segments: [Segment] = []
            var cursor = Decimal.zero
            func append(_ part: BudgetPart, upTo end: Decimal) {
                guard end > cursor else { return }
                segments.append(
                    Segment(end: (end / total).doubleValue, part: part, start: (cursor / total).doubleValue)
                )
                cursor = end
            }
            append(.expenses, upTo: annualExpenses)
            append(.savings, upTo: annualCommitted)
            append(.available, upTo: annualIncome)
            return segments
        }

        private var annualCommitted: Decimal {
            annualExpenses + annualSavings
        }

        private var annualIncome: Decimal {
            budget.income * 12
        }

        private var annualSavings: Decimal {
            (budget.investment ?? 0) * 12
        }

        private func shareLabel(_ line: Line, annual: Decimal) -> ShareLabel {
            let share = abs(line.share)
            switch abs(annual) {
            case 0:
                return .percent(0)
            case annualIncome:
                return .percent(1)
            case let annual where share == 0:
                return annual > annualIncome ? .moreThanOneHundredPercent : .lessThanOnePercent
            case let annual where annual < annualIncome && share >= 1:
                return .moreThanNinetyNinePercent
            case let annual where annual > annualIncome && share <= 1:
                return .moreThanOneHundredPercent
            default:
                return .percent(share)
            }
        }
    }

    enum BudgetChange: Hashable {
        case removeIncome
        case removeInvestments
        case saveIncome
        case saveInvestments
    }

    enum BudgetPart: Hashable {
        case available
        case expenses
        case savings
    }

    @CasePathable
    @dynamicMemberLookup
    enum BudgetStatus: Equatable {
        case failed
        case loaded(Budget?)
        case loading
        case offline
    }

    @CasePathable
    @dynamicMemberLookup
    enum Content: Equatable {
        case expensesOnly(amount: Decimal, income: IncomeStatus)
        case summary(Breakdown)
    }

    enum IncomeStatus: Equatable {
        case failed
        case loading
        case missing
        case offline
    }

    enum Period: CaseIterable, Sendable {
        case day
        case week
        case month
        case year

        func amount(annual: Decimal) -> Decimal {
            let amount =
                switch self {
                case .day: annual / 365
                case .week: annual / 52
                case .month: annual / 12
                case .year: annual
                }
            return amount.rounded(scale: 2)
        }
    }

    @ObservableState
    struct State: Equatable {
        var budgetStatus = BudgetStatus.loading
        @Presents var destination: Destination.State?
        @SharedReader var expenses: IdentifiedArrayOf<Expense>?
        var period = Period.month
        let user: User

        var annualExpenses: Decimal? {
            expenses.map { $0.filter(\.isActive).reduce(0) { $0 + $1.annualAmount } }
        }

        var budget: Budget? {
            budgetStatus.loaded ?? nil
        }

        var content: Content? {
            guard let annualExpenses else { return nil }
            let incomeStatus: IncomeStatus
            switch budgetStatus {
            case .failed:
                incomeStatus = .failed
            case .loaded(let budget?):
                return .summary(Breakdown(annualExpenses: annualExpenses, budget: budget, period: period))
            case .loaded(nil):
                incomeStatus = .missing
            case .loading:
                incomeStatus = .loading
            case .offline:
                incomeStatus = .offline
            }
            return .expensesOnly(amount: period.amount(annual: annualExpenses), income: incomeStatus)
        }

        var isPresenting: Bool {
            destination != nil
        }
    }

    enum Action {
        case addIncomeButtonTapped
        case budgetStreamFailed
        case budgetUpdated(BudgetSnapshot)
        case delegate(Delegate)
        case destination(PresentationAction<Destination.Action>)
        case expensesTileTapped
        case incomeTileTapped
        case periodPickerChanged(Period)
        case savingsTileTapped
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
            case .addIncomeButtonTapped, .incomeTileTapped:
                guard state.destination == nil else { return .none }
                state.destination = .incomeForm(IncomeForm.State(budget: state.budget))
                return .none

            case .budgetStreamFailed:
                guard state.budgetStatus == .loading else { return .none }
                state.budgetStatus = .failed
                return .none

            case .budgetUpdated(.known(let budget)):
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

            case .budgetUpdated(.unknown):
                guard !state.budgetStatus.is(\.loaded) else { return .none }
                state.budgetStatus = .offline
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
                state.destination = nil
                return save(income: income, removingInvestment: false, uid: state.user.uid)

            case .destination(.presented(.incomeForm(.delegate(.didSubmitRemovingInvestment(let income))))):
                state.destination = nil
                return save(income: income, removingInvestment: true, uid: state.user.uid)

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

            case .expensesTileTapped:
                return .send(.delegate(.didSelectExpenses))

            case .periodPickerChanged(let period):
                state.period = period
                return .none

            case .savingsTileTapped:
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

    private func save(income: Decimal, removingInvestment: Bool, uid: String) -> Effect<Action> {
        .merge(
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
