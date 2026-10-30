//
//  BillingCycleTests.swift
//  OverheadTests
//
//  Created by Lorenzo Mazzarotto on 13/10/26.
//

import CustomDump
import Foundation
import Testing

@testable import Overhead

extension BaseSuite {
    @Suite
    struct BillingCycleTests {
        @Test
        func anAmountConvertsToTheOtherCycle() {
            expectNoDifference(BillingCycle.monthly.amount(40, in: .yearly), 480)
            expectNoDifference(BillingCycle.yearly.amount(40, in: .monthly), 3)
            expectNoDifference(BillingCycle.yearly.amount(90, in: .monthly), 8)
            expectNoDifference(BillingCycle.monthly.amount(40, in: .monthly), 40)
            expectNoDifference(BillingCycle.yearly.amount(480, in: .yearly), 480)
        }

        @Test
        func eachCycleHasTheOtherAsItsCounterpart() {
            expectNoDifference(BillingCycle.monthly.counterpart, .yearly)
            expectNoDifference(BillingCycle.yearly.counterpart, .monthly)
        }
    }
}
