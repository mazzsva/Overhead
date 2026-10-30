//
//  BillingCycle.swift
//  Overhead
//
//  Created by Lorenzo Mazzarotto on 03/10/26.
//

import Foundation

enum BillingCycle: String, CaseIterable, Sendable {
    case monthly
    case yearly
}

extension BillingCycle {
    var counterpart: BillingCycle {
        switch self {
        case .monthly: .yearly
        case .yearly: .monthly
        }
    }

    func amount(_ amount: Amount, in cycle: BillingCycle) -> Int {
        let annual =
            switch self {
            case .monthly: amount.value * 12
            case .yearly: amount.value
            }
        return switch cycle {
        case .monthly: (annual + 6) / 12
        case .yearly: annual
        }
    }
}
