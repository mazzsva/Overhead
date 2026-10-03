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
                expenses: SharedReader(value: IdentifiedArray(uniqueElements: [weekly, yearly, .phonePlan]))
            )

            expectNoDifference(state.monthlyTotal, 165)
        }

        @Test
        func theMonthlyTotalIsZeroWithoutActiveExpenses() {
            expectNoDifference(Overview.State(expenses: SharedReader(value: nil)).monthlyTotal, 0)
            expectNoDifference(Overview.State(expenses: SharedReader(value: [])).monthlyTotal, 0)
            expectNoDifference(Overview.State(expenses: SharedReader(value: [.phonePlan])).monthlyTotal, 0)
        }
    }
}
