//
//  AmountInputTests.swift
//  OverheadTests
//
//  Created by Lorenzo Mazzarotto on 12/10/26.
//

import CustomDump
import Foundation
import Testing

@testable import Overhead

extension BaseSuite {
    @Suite
    struct AmountInputTests {
        @Test(
            arguments: [
                ("", AmountInput.empty),
                ("   ", .empty),
                ("0", .incomplete),
                ("00", .incomplete),
                ("1", .valid(1)),
                (" 1,200 ", .valid(1200)),
                ("999999999", .valid(999_999_999)),
                ("1000000000", .refused),
                ("99999999999999999999", .refused),
                ("-10", .refused),
                ("12.5", .refused),
                ("12abc", .refused),
                ("1e3", .refused),
            ]
        )
        func textBecomesAnAmountOrSaysWhyNot(text: String, input: AmountInput) {
            expectNoDifference(AmountInput(text: text, locale: Locale(identifier: "en_US")), input)
        }

        @Test
        func theDecimalSeparatorOfTheLocaleIsRefused() {
            let italian = Locale(identifier: "it_IT")

            expectNoDifference(AmountInput(text: "12,5", locale: italian), .refused)
            expectNoDifference(AmountInput(text: "1.200", locale: italian), .valid(1200))
        }

        @Test
        func anAmountAboveTheLimitIsOverTheLimit() {
            let english = Locale(identifier: "en_US")

            expectNoDifference(AmountInput(text: "3000", locale: english, limit: 3000), .valid(3000))
            expectNoDifference(AmountInput(text: "3,001", locale: english, limit: 3000), .overLimit(3001))
            expectNoDifference(AmountInput(text: "3001", locale: english, limit: 3000).amount, nil)
            expectNoDifference(AmountInput(text: "999999999", locale: english), .valid(.maximum))
        }

        @Test(
            arguments: [
                (AmountInput.empty, false),
                (.incomplete, false),
                (.valid(1), false),
                (.overLimit(3001), true),
                (.refused, true),
            ]
        )
        func onlyAnOverLimitOrRefusedInputIsRefused(input: AmountInput, isRefused: Bool) {
            expectNoDifference(input.isRefused, isRefused)
        }
    }
}
