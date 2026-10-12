//
//  Currency.swift
//  Overhead
//
//  Created by Lorenzo Mazzarotto on 11/10/26.
//

import Foundation

enum Currency: String, CaseIterable, Sendable {
    case brl = "BRL"
    case eur = "EUR"
    case usd = "USD"

    init(locale: Locale) {
        self = locale.currency.flatMap { Currency(rawValue: $0.identifier) } ?? .usd
    }
}

extension FormatStyle where Self == IntegerFormatStyle<Int>.Currency {
    static func currency(_ currency: Currency) -> Self {
        .currency(code: currency.rawValue).presentation(.narrow).precision(.fractionLength(0))
    }
}
