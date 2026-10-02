//
//  DecimalMinorUnitsTests.swift
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
    struct DecimalMinorUnitsTests {
        @Test(arguments: [("EUR", 2), ("JPY", 0), ("KWD", 3)])
        func eachCurrencyHasItsOwnDigits(currencyCode: String, digits: Int) {
            expectNoDifference(Decimal.minorUnitDigits(currencyCode: currencyCode), digits)
        }

        @Test(arguments: ["EUR", "JPY", "KWD"])
        func minorUnitsRoundTripWithoutLoss(currencyCode: String) {
            let amount = Decimal(minorUnits: 123_456, currencyCode: currencyCode)
            expectNoDifference(amount.minorUnits(currencyCode: currencyCode), 123_456)
        }

        @Test
        func anInexactAmountHasNoMinorUnits() {
            expectNoDifference(Decimal(string: "12.345")?.minorUnits(currencyCode: "EUR"), .some(nil))
            expectNoDifference(Decimal(string: "0.5")?.minorUnits(currencyCode: "JPY"), .some(nil))
        }

        @Test
        func anAmountBeyondIntHasNoMinorUnits() {
            let amount = Decimal(Int.max) + 1
            expectNoDifference(amount.minorUnits(currencyCode: "JPY"), nil)
        }
    }
}
