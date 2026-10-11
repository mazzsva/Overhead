//
//  DecimalCentsTests.swift
//  OverheadTests
//
//  Created by Lorenzo Mazzarotto on 02/10/26.
//

import CustomDump
import Foundation
import Testing

@testable import Overhead

extension BaseSuite {
    @Suite
    struct DecimalCentsTests {
        @Test(arguments: [0, 1, -1, 1250, 123_456, Int.max, Int.min])
        func centsRoundTripWithoutLoss(cents: Int) {
            expectNoDifference(Decimal(cents: cents).cents, cents)
        }

        @Test
        func centsKeepTheDecimalValue() throws {
            expectNoDifference(Decimal(cents: 123_456), try #require(Decimal(string: "1234.56")))
            expectNoDifference(try #require(Decimal(string: "12.50")).cents, 1250)
        }

        @Test
        func anAmountWithMoreThanTwoDecimalPlacesHasNoCents() throws {
            let amount = try #require(Decimal(string: "12.345"))
            expectNoDifference(amount.cents, nil)
        }

        @Test
        func anAmountBeyondIntHasNoCents() {
            let amount = Decimal(Int.max) + 1
            expectNoDifference(amount.cents, nil)
        }
    }
}
