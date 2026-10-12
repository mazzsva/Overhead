//
//  Currency+DisplayText.swift
//  Overhead
//
//  Created by Lorenzo Mazzarotto on 12/10/26.
//

import Foundation

extension Currency {
    func displayText(amountText: String, locale: Locale) -> String {
        let parts = amountText.components(separatedBy: locale.decimalSeparator ?? ".")
        guard
            parts.count <= 2,
            parts.allSatisfy({ $0.allSatisfy { $0.isASCII && $0.isNumber } }),
            let value = amountText.isEmpty
                ? Decimal.zero
                : Decimal(string: parts.joined(separator: "."), locale: Locale(identifier: "en_US_POSIX"))
        else { return amountText }
        let fractionDigits = parts.count == 2 ? parts[1].count : 0
        return value.formatted(
            .currency(self)
                .locale(locale)
                .precision(.fractionLength(fractionDigits))
                .decimalSeparator(strategy: parts.count == 2 ? .always : .automatic)
        )
    }
}
