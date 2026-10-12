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
    var title: LocalizedStringResource {
        switch self {
        case .monthly: "Monthly"
        case .yearly: "Yearly"
        }
    }
}
