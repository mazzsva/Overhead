//
//  Decimal+DoubleValue.swift
//  Overhead
//
//  Created by Lorenzo Mazzarotto on 11/10/26.
//

import Foundation

extension Decimal {
    var doubleValue: Double {
        NSDecimalNumber(decimal: self).doubleValue
    }
}
