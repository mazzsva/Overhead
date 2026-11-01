//
//  BillingCycle+Display.swift
//  Overhead
//
//  Created by Lorenzo Mazzarotto on 12/10/26.
//

import SwiftUI

extension BillingCycle {
    var costTitle: LocalizedStringResource {
        switch self {
        case .monthly: "Monthly Cost"
        case .yearly: "Yearly Cost"
        }
    }

    func rate(_ amount: Text) -> Text {
        switch self {
        case .monthly: Text("\(amount) a month")
        case .yearly: Text("\(amount) a year")
        }
    }

    var title: LocalizedStringResource {
        switch self {
        case .monthly: "Monthly"
        case .yearly: "Yearly"
        }
    }
}
