//
//  CurrencyDisplayTextTests.swift
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
    struct CurrencyDisplayTextTests {
        @Test(
            arguments: [
                (Currency.usd, "en_US", "", "$0"),
                (.usd, "en_US", "3200", "$3,200"),
                (.usd, "en_US", "999999999", "$999,999,999"),
                (.usd, "en_US", "12.5", "12.5"),
                (.usd, "en_US", "99999999999999999999", "99999999999999999999"),
                (.eur, "it_IT", "28500", "28.500\u{a0}€"),
                (.brl, "pt_BR", "3200", "R$\u{a0}3.200"),
                (.usd, "de_DE", "", "0\u{a0}$"),
            ]
        )
        func theAmountTextIsFormattedAsTyped(currency: Currency, locale: String, text: String, expected: String) {
            expectNoDifference(currency.displayText(amountText: text, locale: Locale(identifier: locale)), expected)
        }
    }
}
