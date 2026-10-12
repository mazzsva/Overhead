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
                (.usd, "en_US", "3200.5", "$3,200.5"),
                (.usd, "en_US", "1234567.", "$1,234,567."),
                (.usd, "en_US", ".5", "$0.5"),
                (.usd, "en_US", "1.2.3", "1.2.3"),
                (.eur, "it_IT", "28500,5", "28.500,5\u{a0}€"),
                (.brl, "pt_BR", "3200,5", "R$\u{a0}3.200,5"),
                (.usd, "de_DE", "", "0\u{a0}$"),
            ]
        )
        func theAmountTextIsFormattedAsTyped(currency: Currency, locale: String, text: String, expected: String) {
            expectNoDifference(currency.displayText(amountText: text, locale: Locale(identifier: locale)), expected)
        }
    }
}
