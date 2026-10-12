//
//  Budget.swift
//  Overhead
//
//  Created by Lorenzo Mazzarotto on 04/10/26.
//

import Foundation

struct Budget: Equatable, Sendable {
    let income: Amount
    let investment: Amount?

    init?(income: Amount, investment: Amount?) {
        if let investment {
            guard investment <= income else { return nil }
        }
        self.init(validIncome: income, investment: investment)
    }

    private init(validIncome income: Amount, investment: Amount?) {
        self.income = income
        self.investment = investment
    }
}

extension Budget {
    static let mock = Budget(validIncome: 3000, investment: 450)
}
