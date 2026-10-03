//
//  Locale+Currencies.swift
//  Overhead
//
//  Created by Lorenzo Mazzarotto on 03/10/26.
//

import Foundation

extension Locale {
    static let supportedCurrencyCodes = ["BRL", "EUR", "USD"]

    var defaultCurrencyCode: String {
        guard let currencyCode = currency?.identifier, Locale.supportedCurrencyCodes.contains(currencyCode) else {
            return "USD"
        }
        return currencyCode
    }

    func currencyName(for currencyCode: String) -> String {
        localizedString(forCurrencyCode: currencyCode) ?? currencyCode
    }

    func sortedCurrencyCodes(including currencyCode: String) -> [String] {
        Set(Locale.supportedCurrencyCodes + [currencyCode])
            .sorted { currencyName(for: $0).localizedStandardCompare(currencyName(for: $1)) == .orderedAscending }
    }
}
