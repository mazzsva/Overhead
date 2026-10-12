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
    }
}
