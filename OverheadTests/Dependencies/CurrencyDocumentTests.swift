//
//  CurrencyDocumentTests.swift
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
    struct CurrencyDocumentTests {
        @Test
        func aDocumentDecodesIntoACurrency() {
            expectNoDifference(Currency(data: [CurrencyField.currency: "BRL"]), .brl)
            expectNoDifference(Currency(data: [CurrencyField.currency: "EUR", BudgetField.income: 300_000]), .eur)
        }

        @Test
        func aProfileWithoutACurrencyHasNoCurrency() {
            expectNoDifference(Currency(data: [BudgetField.income: 300_000]), nil)
        }

        @Test(arguments: ["GBP", "usd", 1] as [any Sendable])
        func anInvalidCurrencyIsSkipped(value: any Sendable) {
            var currency: Currency? = .usd
            withKnownIssue {
                currency = Currency(data: [CurrencyField.currency: value])
            }
            expectNoDifference(currency, nil)
        }
    }
}
