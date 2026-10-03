//
//  Decimal+Cents.swift
//  Overhead
//
//  Created by Lorenzo Mazzarotto on 02/10/26.
//

import Foundation

extension Decimal {
    init(cents: Int) {
        self.init(sign: .plus, exponent: -2, significand: Decimal(cents))
    }

    var cents: Int? {
        let scaled = Decimal(sign: .plus, exponent: 2, significand: self)
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

extension FormatStyle where Self == Decimal.FormatStyle.Currency {
    static var dollars: Self {
        .currency(code: "USD").presentation(.narrow)
    }
}
