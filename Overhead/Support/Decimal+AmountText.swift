//
//  Decimal+AmountText.swift
//  Overhead
//
//  Created by Lorenzo Mazzarotto on 04/10/26.
//

import Foundation
import RegexBuilder

extension Decimal {
    init?(amountText: String, locale: Locale) {
        let text = amountText.trimmingCharacters(in: .whitespacesAndNewlines)
        let number = Regex { Capture { Decimal.FormatStyle(locale: locale) } }
        guard
            let amount = text.wholeMatch(of: number)?.output.1,
            amount > 0,
            amount.cents != nil
        else { return nil }
        self = amount
    }

    func amountText(locale: Locale) -> String {
        formatted(
            .number
                .grouping(.never)
                .locale(locale)
                .precision(.fractionLength(2))
        )
    }
}
