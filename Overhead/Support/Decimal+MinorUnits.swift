//
//  Decimal+MinorUnits.swift
//  Overhead
//
//  Created by Lorenzo Mazzarotto on 02/10/26.
//

import Foundation

extension Decimal {
    init(minorUnits: Int, currencyCode: String) {
        self.init(
            sign: .plus,
            exponent: -Self.minorUnitDigits(currencyCode: currencyCode),
            significand: Decimal(minorUnits)
        )
    }

    static func minorUnitDigits(currencyCode: String) -> Int {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = currencyCode
        return formatter.maximumFractionDigits
    }

    func minorUnits(currencyCode: String) -> Int? {
        let scaled = Decimal(
            sign: .plus,
            exponent: Self.minorUnitDigits(currencyCode: currencyCode),
            significand: self
        )
        var source = scaled
        var whole = Decimal()
        NSDecimalRound(&whole, &source, 0, .plain)
        guard
            whole == scaled,
            whole >= Decimal(Int.min),
            whole <= Decimal(Int.max)
        else { return nil }
        return NSDecimalNumber(decimal: whole).intValue
    }
}
