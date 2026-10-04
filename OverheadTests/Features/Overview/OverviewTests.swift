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

            let state = Overview.State(
                expenses: SharedReader(value: IdentifiedArray(uniqueElements: [weekly, yearly, .phonePlan])),
                user: .mock
            )

            expectNoDifference(state.monthlyTotal, 165)
        }

        @Test
        func theMonthlyTotalIsZeroWithoutActiveExpenses() {
            expectNoDifference(Overview.State(expenses: SharedReader(value: nil), user: .mock).monthlyTotal, 0)
            expectNoDifference(Overview.State(expenses: SharedReader(value: []), user: .mock).monthlyTotal, 0)
            expectNoDifference(
                Overview.State(expenses: SharedReader(value: [.phonePlan]), user: .mock).monthlyTotal,
                0
            )
        }

        @Test
        func leftToSpendSubtractsTheExpensesAndTheInvestmentFromTheIncome() {
            var state = Overview.State(
                expenses: SharedReader(value: IdentifiedArray(uniqueElements: Expense.mocks)),
                user: .mock
            )
            expectNoDifference(state.activeExpenseCount, 2)
            expectNoDifference(state.leftToSpend, nil)
            expectNoDifference(state.expensesShare, nil)

            state.budgetStatus = .loaded(nil)
            expectNoDifference(state.leftToSpend, nil)

            state.budgetStatus = .loaded(Budget(income: 3000, investment: 450))
            expectNoDifference(state.leftToSpend, Decimal(cents: 156_010))
            expectNoDifference(state.expensesShare, Decimal(cents: 98_990) / 3000)
            expectNoDifference(state.investmentShare, Decimal(string: "0.15"))
            expectNoDifference(state.leftToSpendShare, Decimal(cents: 156_010) / 3000)

            state.budgetStatus = .loaded(Budget(income: 3000, investment: nil))
            expectNoDifference(state.leftToSpend, Decimal(cents: 201_010))
            expectNoDifference(state.investmentShare, nil)

            state.budgetStatus = .loaded(Budget(income: 900, investment: 100))
            expectNoDifference(state.leftToSpend, Decimal(cents: -18_990))
        }

        @Test
        func theTaskObservesTheBudget() async {
            let budget = AsyncThrowingStream<Budget?, any Error>.makeStream()

            let store = TestStore(
                initialState: Overview.State(expenses: SharedReader(value: nil), user: .mock)
            ) {
                Overview()
            } withDependencies: {
                $0.budgetClient.budget = { uid in
                    expectNoDifference(uid, User.mock.uid)
                    return budget.stream
                }
            }

            await store.send(.task)

            budget.continuation.yield(nil)
            await store.receive(\.budgetUpdated) {
                $0.budgetStatus = .loaded(nil)
            }

            budget.continuation.yield(.mock)
            await store.receive(\.budgetUpdated) {
                $0.budgetStatus = .loaded(.mock)
            }

            budget.continuation.finish()
            await store.finish()
        }

        @Test
        func aFailedStreamKeepsTheBudgetAndRetriesAfterFiveSeconds() async {
            let clock = TestClock()
            let hasFailed = LockIsolated(false)

            let store = TestStore(
                initialState: Overview.State(
                    budgetStatus: .loaded(.mock), expenses: SharedReader(value: nil), user: .mock)
            ) {
                Overview()
            } withDependencies: {
                $0.budgetClient.budget = { _ in
                    let isFirstAttempt = hasFailed.withValue { failed -> Bool in
                        defer { failed = true }
                        return !failed
                    }
                    return AsyncThrowingStream { continuation in
                        isFirstAttempt
                            ? continuation.finish(throwing: BudgetFailure())
                            : continuation.finish()
                    }
                }
                $0.continuousClock = clock
            }

            await store.send(.task)
            await store.receive(\.budgetStreamFailed)

            await clock.advance(by: .seconds(5))
            await store.receive(\.budgetRetryTimerElapsed)
            await store.finish()
        }

        @Test
        func theExpensesRowAsksToShowTheExpenses() async {
            let store = TestStore(
                initialState: Overview.State(expenses: SharedReader(value: nil), user: .mock)
            ) {
                Overview()
            }

            await store.send(.expensesRowTapped)
            await store.receive(\.delegate.didSelectExpenses)
        }

        private struct BudgetFailure: Error {}
    }
}
