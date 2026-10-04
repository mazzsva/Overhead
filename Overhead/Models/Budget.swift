//
//  Budget.swift
//  Overhead
//
//  Created by Lorenzo Mazzarotto on 04/10/26.
//

import Foundation

struct Budget: Equatable, Sendable {
    var income: Decimal
    var investment: Decimal?
}

extension Budget {
    static let mock = Budget(income: 3000, investment: 450)
}
