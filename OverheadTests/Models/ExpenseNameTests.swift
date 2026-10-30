//
//  ExpenseNameTests.swift
//  OverheadTests
//
//  Created by Lorenzo Mazzarotto on 12/10/26.
//

import CustomDump
import Testing

@testable import Overhead

extension BaseSuite {
    @Suite
    struct ExpenseNameTests {
        @Test(arguments: ["Gym", "  Gym \n", "\tGym  "])
        func theNameIsTrimmed(text: String) {
            expectNoDifference(ExpenseName(value: text)?.value, "Gym")
        }

        @Test(arguments: ["", "   ", " \n\t "])
        func aBlankNameIsRefused(text: String) {
            expectNoDifference(ExpenseName(value: text), nil)
        }

        @Test
        func theNameCannotBeLongerThanTheLimit() {
            let longest = String(repeating: "a", count: ExpenseName.maximumLength)

            expectNoDifference(ExpenseName(value: longest)?.value, longest)
            expectNoDifference(ExpenseName(value: longest + "a"), nil)
            expectNoDifference(ExpenseName(value: "  " + longest + "  ")?.value, longest)
        }

        @Test
        func theLimitCountsUTF16CodeUnits() {
            let longest = String(repeating: "👍🏽", count: ExpenseName.maximumLength / 4)

            expectNoDifference(ExpenseName(value: longest)?.value, longest)
            expectNoDifference(ExpenseName(value: longest + "👍🏽"), nil)
        }
    }
}
