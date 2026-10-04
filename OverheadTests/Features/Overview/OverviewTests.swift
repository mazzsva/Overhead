//
//  OverviewTests.swift
//  OverheadTests
//
//  Created by Lorenzo Mazzarotto on 04/10/26.
//

import ComposableArchitecture
import CustomDump
import Foundation
import Testing

@testable import Overhead

extension BaseSuite {
    @Suite
    @MainActor
    struct OverviewTests {
        @Test
        func theMonthlyTotalAddsTheMonthlyAmountOfEachActiveExpense() {
            var weekly = Expense.gym
            weekly.billingCycle = .weekly
            weekly.amount = 15
            var yearly = Expense.rent
            yearly.billingCycle = .yearly
            yearly.amount = 1200

            let state = makeState(expenses: [weekly, yearly, .phonePlan])

            expectNoDifference(state.monthlyTotal, 165)
        }

        @Test
        func theMonthlyTotalIsRoundedToCents() {
            var weekly = Expense.gym
            weekly.billingCycle = .weekly
            weekly.amount = 5

            let state = makeState(expenses: [weekly])

            expectNoDifference(state.monthlyTotal, Decimal(cents: 2167))
        }

        @Test
        func theMonthlyTotalIsUnknownWithoutExpenses() {
            expectNoDifference(makeState(expenses: nil).monthlyTotal, nil)
            expectNoDifference(makeState(expenses: []).monthlyTotal, 0)
            expectNoDifference(makeState(expenses: [.phonePlan]).monthlyTotal, 0)
        }

        @Test
        func theBreakdownNeedsTheBudgetAndTheExpenses() {
            expectNoDifference(makeState(.loading, expenses: Expense.mocks).breakdown, nil)
            expectNoDifference(makeState(.failed, expenses: Expense.mocks).breakdown, nil)
            expectNoDifference(makeState(.loaded(nil), expenses: Expense.mocks).breakdown, nil)
            expectNoDifference(makeState(.loaded(.mock), expenses: nil).breakdown, nil)
        }

        @Test
        func theBreakdownSubtractsTheExpensesAndTheInvestmentFromTheIncome() {
            let state = makeState(.loaded(.mock), expenses: Expense.mocks)

            expectNoDifference(state.activeExpenseCount, 2)
            let breakdown = state.breakdown
            expectNoDifference(breakdown?.income, 3000)
            expectNoDifference(breakdown?.expenses, .init(amount: Decimal(cents: -98_990), share: percent(33)))
            expectNoDifference(breakdown?.investments, .init(amount: -450, share: percent(15)))
            expectNoDifference(breakdown?.leftToSpend, .init(amount: Decimal(cents: 156_010), share: percent(52)))
            expectNoDifference(breakdown?.isOverBudget, false)
            expectNoDifference(
                breakdown?.chartSegments,
                [
                    .init(amount: Decimal(cents: 98_990), part: .expenses),
                    .init(amount: 450, part: .investments),
                    .init(amount: Decimal(cents: 156_010), part: .leftToSpend),
                ]
            )
            expectNoDifference(breakdown?.chartUpperBound, 3000)
        }

        @Test
        func theSharesAlwaysAddUpToTheWhole() throws {
            let breakdown = Overview.Breakdown(
                budget: try #require(Budget(income: 3000, investment: Decimal(cents: 100_050))),
                monthlyTotal: Decimal(cents: 100_050)
            )

            expectNoDifference(breakdown.expenses.share, percent(33))
            expectNoDifference(breakdown.investments?.share, percent(33))
            expectNoDifference(breakdown.leftToSpend.share, percent(34))
        }

        @Test
        func aBudgetWithoutInvestmentHasNoInvestmentLine() throws {
            let budget = try #require(Budget(income: 3000, investment: nil))
            let breakdown = Overview.Breakdown(budget: budget, monthlyTotal: 1000)

            expectNoDifference(breakdown.investments, nil)
            expectNoDifference(breakdown.leftToSpend, .init(amount: 2000, share: percent(67)))
            expectNoDifference(
                breakdown.chartSegments,
                [.init(amount: 1000, part: .expenses), .init(amount: 2000, part: .leftToSpend)]
            )
        }

        @Test
        func costsAboveTheIncomeFillTheChartWithoutANegativePart() throws {
            let budget = try #require(Budget(income: 900, investment: 100))
            let breakdown = Overview.Breakdown(budget: budget, monthlyTotal: 1000)

            expectNoDifference(breakdown.leftToSpend.amount, -200)
            #expect(breakdown.isOverBudget)
            expectNoDifference(
                breakdown.chartSegments,
                [.init(amount: 1000, part: .expenses), .init(amount: 100, part: .investments)]
            )
            expectNoDifference(breakdown.chartUpperBound, 1100)
        }

        @Test
        func theTaskObservesTheBudget() async {
            let budget = AsyncThrowingStream<BudgetSnapshot, any Error>.makeStream()

            let store = TestStore(initialState: makeState()) {
                Overview()
            } withDependencies: {
                $0.budgetClient.budget = { uid in
                    expectNoDifference(uid, User.mock.uid)
                    return budget.stream
                }
            }

            let task = await store.send(.task)

            budget.continuation.yield(BudgetSnapshot(budget: nil, isFromCache: false))
            await store.receive(\.budgetUpdated) {
                $0.budgetStatus = .loaded(nil)
            }

            budget.continuation.yield(BudgetSnapshot(budget: .mock, isFromCache: false))
            await store.receive(\.budgetUpdated) {
                $0.budgetStatus = .loaded(.mock)
            }

            await task.cancel()
        }

        @Test
        func aCachedMissingBudgetBeforeAnyLoadMeansOffline() async {
            let store = TestStore(initialState: makeState()) {
                Overview()
            }

            await store.send(.budgetUpdated(BudgetSnapshot(budget: nil, isFromCache: true))) {
                $0.budgetStatus = .offline
            }
            await store.send(.budgetUpdated(BudgetSnapshot(budget: nil, isFromCache: false))) {
                $0.budgetStatus = .loaded(nil)
            }
        }

        @Test
        func aCachedBudgetLoadsWhileOffline() async {
            let store = TestStore(initialState: makeState()) {
                Overview()
            }

            await store.send(.budgetUpdated(BudgetSnapshot(budget: .mock, isFromCache: true))) {
                $0.budgetStatus = .loaded(.mock)
            }
        }

        @Test
        func aBudgetRemovedOfflineDisappearsAtOnce() async {
            let store = TestStore(initialState: makeState(.loaded(.mock))) {
                Overview()
            }

            await store.send(.budgetUpdated(BudgetSnapshot(budget: nil, isFromCache: true))) {
                $0.budgetStatus = .loaded(nil)
            }
        }

        @Test
        func aFailedFirstLoadShowsTheFailureAndRetriesAfterFiveSeconds() async {
            let clock = TestClock()
            let attempts = LockIsolated(0)

            let store = TestStore(initialState: makeState()) {
                Overview()
            } withDependencies: {
                $0.budgetClient.budget = { _ in
                    let attempt = attempts.withValue {
                        $0 += 1
                        return $0
                    }
                    return AsyncThrowingStream { continuation in
                        if attempt == 1 {
                            continuation.finish(throwing: BudgetFailure())
                        } else {
                            continuation.yield(BudgetSnapshot(budget: .mock, isFromCache: false))
                            continuation.finish()
                        }
                    }
                }
                $0.continuousClock = clock
            }

            await store.send(.task)
            await store.receive(\.budgetStreamFailed) {
                $0.budgetStatus = .failed
            }

            await clock.advance(by: .seconds(4))
            expectNoDifference(attempts.value, 1)

            await clock.advance(by: .seconds(1))
            await store.receive(\.budgetUpdated) {
                $0.budgetStatus = .loaded(.mock)
            }
            await store.finish()
            expectNoDifference(attempts.value, 2)
        }

        @Test
        func aFailedStreamKeepsTheBudget() async {
            let clock = TestClock()
            let attempts = LockIsolated(0)

            let store = TestStore(initialState: makeState(.loaded(.mock))) {
                Overview()
            } withDependencies: {
                $0.budgetClient.budget = { _ in
                    let attempt = attempts.withValue {
                        $0 += 1
                        return $0
                    }
                    return AsyncThrowingStream { continuation in
                        attempt == 1 ? continuation.finish(throwing: BudgetFailure()) : continuation.finish()
                    }
                }
                $0.continuousClock = clock
            }

            await store.send(.task)
            await store.receive(\.budgetStreamFailed)
            await clock.advance(by: .seconds(5))
            await store.finish()
            expectNoDifference(attempts.value, 2)
        }

        @Test
        func cancellingTheTaskStopsTheRetry() async {
            let clock = TestClock()
            let attempts = LockIsolated(0)

            let store = TestStore(initialState: makeState()) {
                Overview()
            } withDependencies: {
                $0.budgetClient.budget = { _ in
                    attempts.withValue { $0 += 1 }
                    return AsyncThrowingStream { continuation in
                        continuation.finish(throwing: BudgetFailure())
                    }
                }
                $0.continuousClock = clock
            }

            let task = await store.send(.task)
            await store.receive(\.budgetStreamFailed) {
                $0.budgetStatus = .failed
            }
            await task.cancel()
            await clock.advance(by: .seconds(5))
            expectNoDifference(attempts.value, 1)
        }

        @Test
        func theExpensesRowAsksToShowTheExpenses() async {
            let store = TestStore(initialState: makeState()) {
                Overview()
            }

            await store.send(.expensesRowTapped)
            await store.receive(\.delegate.didSelectExpenses)
        }

        @Test
        func theAddIncomeButtonOpensAnEmptyIncomeForm() async {
            let store = TestStore(initialState: makeState(.loaded(nil))) {
                Overview()
            }

            await store.send(.addIncomeButtonTapped) {
                $0.destination = .incomeForm(IncomeForm.State(budget: nil))
            }
        }

        @Test
        func eachRowOpensItsOwnForm() async {
            let store = TestStore(initialState: makeState(.loaded(.mock))) {
                Overview()
            }

            await store.send(.incomeRowTapped) {
                $0.destination = .incomeForm(IncomeForm.State(budget: .mock))
            }
            await store.send(.destination(.dismiss)) {
                $0.destination = nil
            }
            await store.send(.investmentsRowTapped) {
                $0.destination = .investmentForm(InvestmentForm.State(income: 3000, investment: 450))
            }
        }

        @Test
        func theInvestmentsNeedAnIncome() async {
            let store = TestStore(initialState: makeState(.loaded(nil))) {
                Overview()
            }

            await store.send(.investmentsRowTapped)
        }

        @Test
        func theInvestmentsRowWithoutInvestmentsOpensAnEmptyForm() async throws {
            let budget = try #require(Budget(income: 3000, investment: nil))
            let store = TestStore(initialState: makeState(.loaded(budget))) {
                Overview()
            }

            await store.send(.investmentsRowTapped) {
                $0.destination = .investmentForm(InvestmentForm.State(income: 3000, investment: nil))
            }
        }

        @Test
        func aSecondTapDoesNotReplaceTheOpenForm() async {
            let store = TestStore(initialState: makeState(.loaded(.mock))) {
                Overview()
            }

            await store.send(.incomeRowTapped) {
                $0.destination = .incomeForm(IncomeForm.State(budget: .mock))
            }
            await store.send(.investmentsRowTapped)
            await store.send(.addIncomeButtonTapped)
        }

        @Test
        func anOpenFormFollowsTheBudget() async throws {
            var state = makeState(.loaded(.mock))
            state.destination = .incomeForm(IncomeForm.State(budget: .mock))
            let store = TestStore(initialState: state) {
                Overview()
            }

            let raised = try #require(Budget(income: 3000, investment: 600))
            await store.send(.budgetUpdated(BudgetSnapshot(budget: raised, isFromCache: false))) {
                $0.budgetStatus = .loaded(raised)
                $0.destination?.modify(\.incomeForm) { $0.investment = 600 }
            }

            await store.send(.destination(.dismiss)) {
                $0.destination = nil
            }
            await store.send(.investmentsRowTapped) {
                $0.destination = .investmentForm(InvestmentForm.State(income: 3000, investment: 600))
            }
            let promoted = try #require(Budget(income: 4000, investment: 600))
            await store.send(.budgetUpdated(BudgetSnapshot(budget: promoted, isFromCache: false))) {
                $0.budgetStatus = .loaded(promoted)
                $0.destination?.modify(\.investmentForm) { $0.income = 4000 }
            }
            await store.send(.budgetUpdated(BudgetSnapshot(budget: nil, isFromCache: false))) {
                $0.budgetStatus = .loaded(nil)
                $0.destination = nil
            }
        }

        @Test
        func savingTheIncomeWritesOnlyTheIncome() async {
            var state = makeState(.loaded(.mock))
            state.destination = .incomeForm(IncomeForm.State(budget: .mock))
            let calls = LockIsolated<[String]>([])

            let store = TestStore(initialState: state) {
                Overview()
            } withDependencies: {
                $0.budgetClient.saveIncome = { income, removingInvestment, uid in
                    calls.withValue { $0.append("saveIncome \(income) \(removingInvestment) \(uid)") }
                }
                $0.hapticsClient.success = { calls.withValue { $0.append("success") } }
            }

            await store.send(.destination(.presented(.incomeForm(.delegate(.didSubmit(3500)))))) {
                $0.destination = nil
            }
            await store.finish()
            expectNoDifference(calls.value.sorted(), ["saveIncome 3500 false \(User.mock.uid)", "success"])
        }

        @Test
        func savingTheIncomeCanRemoveTheInvestmentInTheSameWrite() async {
            var state = makeState(.loaded(.mock))
            state.destination = .incomeForm(IncomeForm.State(budget: .mock))
            let calls = LockIsolated<[String]>([])

            let store = TestStore(initialState: state) {
                Overview()
            } withDependencies: {
                $0.budgetClient.saveIncome = { income, removingInvestment, uid in
                    calls.withValue { $0.append("saveIncome \(income) \(removingInvestment) \(uid)") }
                }
                $0.hapticsClient.success = { calls.withValue { $0.append("success") } }
            }

            await store.send(.destination(.presented(.incomeForm(.delegate(.didSubmitRemovingInvestment(400)))))) {
                $0.destination = nil
            }
            await store.finish()
            expectNoDifference(calls.value.sorted(), ["saveIncome 400 true \(User.mock.uid)", "success"])
        }

        @Test
        func savingTheInvestmentWritesOnlyTheInvestment() async {
            var state = makeState(.loaded(.mock))
            state.destination = .investmentForm(InvestmentForm.State(income: 3000, investment: 450))
            let calls = LockIsolated<[String]>([])

            let store = TestStore(initialState: state) {
                Overview()
            } withDependencies: {
                $0.budgetClient.saveInvestment = { investment, uid in
                    calls.withValue { $0.append("saveInvestment \(investment) \(uid)") }
                }
                $0.hapticsClient.success = { calls.withValue { $0.append("success") } }
            }

            await store.send(.destination(.presented(.investmentForm(.delegate(.didSubmit(300)))))) {
                $0.destination = nil
            }
            await store.finish()
            expectNoDifference(calls.value.sorted(), ["saveInvestment 300 \(User.mock.uid)", "success"])
        }

        @Test
        func removingTheInvestmentKeepsTheIncome() async {
            var state = makeState(.loaded(.mock))
            state.destination = .investmentForm(InvestmentForm.State(income: 3000, investment: 450))
            let calls = LockIsolated<[String]>([])

            let store = TestStore(initialState: state) {
                Overview()
            } withDependencies: {
                $0.budgetClient.removeInvestment = { uid in
                    calls.withValue { $0.append("removeInvestment \(uid)") }
                }
                $0.hapticsClient.warning = { calls.withValue { $0.append("warning") } }
            }

            await store.send(.destination(.presented(.investmentForm(.delegate(.didRemove))))) {
                $0.destination = nil
            }
            await store.finish()
            expectNoDifference(calls.value.sorted(), ["removeInvestment \(User.mock.uid)", "warning"])
        }

        @Test
        func removingTheIncomeDeletesTheBudget() async {
            var state = makeState(.loaded(.mock))
            state.destination = .incomeForm(IncomeForm.State(budget: .mock))
            let calls = LockIsolated<[String]>([])

            let store = TestStore(initialState: state) {
                Overview()
            } withDependencies: {
                $0.budgetClient.delete = { uid in
                    calls.withValue { $0.append("delete \(uid)") }
                }
                $0.hapticsClient.warning = { calls.withValue { $0.append("warning") } }
            }

            await store.send(.destination(.presented(.incomeForm(.delegate(.didRemove))))) {
                $0.destination = nil
            }
            await store.finish()
            expectNoDifference(calls.value.sorted(), ["delete \(User.mock.uid)", "warning"])
        }

        @Test
        func aFailedChangeTellsTheParentWhichChangeFailed() async {
            await expectFailure(
                of: .destination(.presented(.incomeForm(.delegate(.didRemove)))),
                in: .incomeForm(IncomeForm.State(budget: .mock)),
                reports: .removeIncome
            )
            await expectFailure(
                of: .destination(.presented(.incomeForm(.delegate(.didSubmit(3500))))),
                in: .incomeForm(IncomeForm.State(budget: .mock)),
                reports: .saveIncome
            )
            await expectFailure(
                of: .destination(.presented(.investmentForm(.delegate(.didRemove)))),
                in: .investmentForm(InvestmentForm.State(income: 3000, investment: 450)),
                reports: .removeInvestments
            )
            await expectFailure(
                of: .destination(.presented(.investmentForm(.delegate(.didSubmit(300))))),
                in: .investmentForm(InvestmentForm.State(income: 3000, investment: 450)),
                reports: .saveInvestments
            )
        }

        private func expectFailure(
            of action: Overview.Action,
            in destination: Overview.Destination.State,
            reports change: Overview.BudgetChange
        ) async {
            var state = makeState(.loaded(.mock))
            state.destination = destination

            let store = TestStore(initialState: state) {
                Overview()
            } withDependencies: {
                $0.budgetClient.delete = { _ in throw BudgetFailure() }
                $0.budgetClient.removeInvestment = { _ in throw BudgetFailure() }
                $0.budgetClient.saveIncome = { _, _, _ in throw BudgetFailure() }
                $0.budgetClient.saveInvestment = { _, _ in throw BudgetFailure() }
                $0.hapticsClient.success = {}
                $0.hapticsClient.warning = {}
            }

            await store.send(action) {
                $0.destination = nil
            }
            await store.receive(\.delegate.didFailToChangeBudget, change)
            await store.finish()
        }

        private func makeState(
            _ budgetStatus: Overview.BudgetStatus = .loading,
            expenses: [Expense]? = nil
        ) -> Overview.State {
            Overview.State(
                budgetStatus: budgetStatus,
                expenses: SharedReader(value: expenses.map { IdentifiedArray(uniqueElements: $0) }),
                user: .mock
            )
        }

        private func percent(_ value: Int) -> Decimal {
            Decimal(value) / 100
        }

        private struct BudgetFailure: Error {}
    }
}
