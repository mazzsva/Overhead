//
//  Decimal+Rounded.swift
//  Overhead
//
//  Created by Lorenzo Mazzarotto on 02/10/26.
//

import Foundation

extension Decimal {
    func rounded(scale: Int) -> Decimal {
        var source = self
        var result = Decimal()
        NSDecimalRound(&result, &source, scale, .plain)
        return result
    }
}
