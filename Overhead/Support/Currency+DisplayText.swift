//
//  Currency+DisplayText.swift
//  Overhead
//
//  Created by Lorenzo Mazzarotto on 12/10/26.
//

import Foundation

extension Currency {
    func displayText(amountText: String, locale: Locale) -> String {
        guard
            amountText.allSatisfy({ $0.isASCII && $0.isNumber }),
            let value = amountText.isEmpty ? 0 : Int(amountText)
        else { return amountText }
        return value.formatted(.currency(self).locale(locale))
    }
}
