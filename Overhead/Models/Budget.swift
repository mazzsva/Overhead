//
//  Budget.swift
//  Overhead
//
//  Created by Lorenzo Mazzarotto on 04/10/26.
//

import Foundation

struct Budget: Equatable, Sendable {
    let income: Decimal
    let investment: Decimal?

    init?(income: Decimal, investment: Decimal?) {
        guard income > 0, income.cents != nil else { return nil }
        if let investment {
            guard investment > 0, investment <= income, investment.cents != nil else { return nil }
        }
        self.init(validIncome: income, investment: investment)
    }

    private init(validIncome income: Decimal, investment: Decimal?) {
        self.income = income
        self.investment = investment
    }
}

extension Budget {
    static let mock = Budget(validIncome: 3000, investment: 450)
}
