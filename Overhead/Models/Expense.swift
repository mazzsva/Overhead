//
//  Expense.swift
//  Overhead
//
//  Created by Lorenzo Mazzarotto on 13/07/26.
//

import Dependencies
import Foundation

struct Expense: Equatable, Identifiable, Sendable {
    var amount: Decimal
    var billingCycle: BillingCycle
    let createdAt: Date
    let id: UUID
    var isActive: Bool
    var name: String
}

extension Expense {
    var monthlyAmount: Decimal {
        switch billingCycle {
        case .weekly: amount * 52 / 12
        case .monthly: amount
        case .yearly: amount / 12
        }
    }

    static func listOrder(_ lhs: Expense, _ rhs: Expense) -> Bool {
        if lhs.isActive != rhs.isActive {
            return lhs.isActive
        }
        if lhs.monthlyAmount != rhs.monthlyAmount {
            return lhs.monthlyAmount > rhs.monthlyAmount
        }
        return lhs.name.localizedStandardCompare(rhs.name) == .orderedAscending
    }
}

extension Expense {
    static let rent = Expense(
        amount: 950,
        billingCycle: .monthly,
        createdAt: Date(timeIntervalSince1970: 1_750_000_000),
        id: UUID(0),
        isActive: true,
        name: "Rent"
    )

    static let gym = Expense(
        amount: Decimal(cents: 3990),
        billingCycle: .monthly,
        createdAt: Date(timeIntervalSince1970: 1_749_000_000),
        id: UUID(1),
        isActive: true,
        name: "Gym"
    )

    static let phonePlan = Expense(
        amount: Decimal(cents: 1299),
        billingCycle: .monthly,
        createdAt: Date(timeIntervalSince1970: 1_748_000_000),
        id: UUID(2),
        isActive: false,
        name: "Phone Plan"
    )

    static let mocks: [Expense] = [.rent, .gym, .phonePlan]
}
