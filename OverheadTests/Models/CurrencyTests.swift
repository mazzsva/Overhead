//
//  CurrencyTests.swift
//  OverheadTests
//
//  Created by Lorenzo Mazzarotto on 11/10/26.
//

import CustomDump
import Foundation
import Testing

@testable import Overhead

extension BaseSuite {
    @Suite
    struct CurrencyTests {
        @Test(arguments: [
            (Currency.usd, "en_US", "$1,234"),
            (Currency.usd, "en_CA", "$1,234"),
            (Currency.usd, "en_AU", "$1,234"),
            (Currency.usd, "es_MX", "$1,234"),
            (Currency.usd, "ja_JP", "$1,234"),
            (Currency.usd, "pt_BR", "$\u{00A0}1.234"),
            (Currency.usd, "it_IT", "1234\u{00A0}$"),
            (Currency.eur, "en_US", "€1,234"),
            (Currency.eur, "pt_BR", "€\u{00A0}1.234"),
            (Currency.eur, "it_IT", "1234\u{00A0}€"),
            (Currency.brl, "en_US", "R$1,234"),
            (Currency.brl, "pt_BR", "R$\u{00A0}1.234"),
            (Currency.brl, "it_IT", "1234\u{00A0}R$"),
        ])
        func everyLocaleShowsOnlyTheCurrencySymbol(currency: Currency, identifier: String, expected: String) {
            let text = 1234.formatted(.currency(currency).locale(Locale(identifier: identifier)))
            expectNoDifference(text, expected)
        }

        @Test(arguments: [
            ("en_US", Currency.usd),
            ("it_IT", Currency.eur),
            ("pt_BR", Currency.brl),
            ("ja_JP", Currency.usd),
        ])
        func theDefaultCurrencyFollowsTheRegion(identifier: String, expected: Currency) {
            expectNoDifference(Currency(locale: Locale(identifier: identifier)), expected)
        }
    }
}
