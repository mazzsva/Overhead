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
        func theSharesAlwaysAddUpToTheWhole() {
            let breakdown = Overview.Breakdown(
                budget: Budget(income: 3000, investment: Decimal(cents: 100_050)),
                monthlyTotal: Decimal(cents: 100_050)
            )

            expectNoDifference(breakdown.expenses.share, percent(33))
            expectNoDifference(breakdown.investments?.share, percent(33))
            expectNoDifference(breakdown.leftToSpend.share, percent(34))
        }

        @Test
        func aBudgetWithoutInvestmentHasNoInvestmentLine() {
            let breakdown = Overview.Breakdown(budget: Budget(income: 3000, investment: nil), monthlyTotal: 1000)

            expectNoDifference(breakdown.investments, nil)
            expectNoDifference(breakdown.leftToSpend, .init(amount: 2000, share: percent(67)))
            expectNoDifference(
                breakdown.chartSegments,
                [.init(amount: 1000, part: .expenses), .init(amount: 2000, part: .leftToSpend)]
            )
        }

        @Test
        func costsAboveTheIncomeFillTheChartWithoutANegativePart() {
            let breakdown = Overview.Breakdown(budget: Budget(income: 900, investment: 100), monthlyTotal: 1000)

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
            let budget = AsyncThrowingStream<Budget?, any Error>.makeStream()

            let store = TestStore(initialState: makeState()) {
                Overview()
            } withDependencies: {
                $0.budgetClient.budget = { uid in
                    expectNoDifference(uid, User.mock.uid)
                    return budget.stream
                }
            }

            let task = await store.send(.task)

            budget.continuation.yield(nil)
            await store.receive(\.budgetUpdated) {
                $0.budgetStatus = .loaded(nil)
            }

            budget.continuation.yield(.mock)
            await store.receive(\.budgetUpdated) {
                $0.budgetStatus = .loaded(.mock)
            }

            await task.cancel()
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
                            continuation.yield(.mock)
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
