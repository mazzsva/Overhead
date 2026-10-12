//
//  AmountTests.swift
//  OverheadTests
//
//  Created by Lorenzo Mazzarotto on 12/10/26.
//

import CustomDump
import Testing

@testable import Overhead

extension BaseSuite {
    @Suite
    struct AmountTests {
        @Test(arguments: [-1, 0, 1_000_000_000])
        func anAmountOutsideTheRangeIsRefused(value: Int) {
            expectNoDifference(Amount(value: value), nil)
        }

        @Test(arguments: [1, 999_999_999])
        func anAmountInsideTheRangeKeepsItsValue(value: Int) {
            expectNoDifference(Amount(value: value)?.value, value)
        }
    }
}
