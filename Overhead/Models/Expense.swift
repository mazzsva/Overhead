//
//  Expense.swift
//  Overhead
//
//  Created by Lorenzo Mazzarotto on 13/07/26.
//

import Dependencies
import Foundation

struct Expense: Equatable, Identifiable, Sendable {
    var amount: Amount
    var billingCycle: BillingCycle
    let createdAt: Date
    let id: UUID
    var isActive: Bool
    var name: ExpenseName
}

extension Expense {
    var annualAmount: Int {
        billingCycle.amount(amount, in: .yearly)
    }

    static func listOrder(_ lhs: Expense, _ rhs: Expense) -> Bool {
        if lhs.annualAmount != rhs.annualAmount {
            return lhs.annualAmount > rhs.annualAmount
        }
        switch lhs.name.value.localizedStandardCompare(rhs.name.value) {
        case .orderedAscending:
            return true
        case .orderedDescending:
            return false
        case .orderedSame:
            break
        }
        if lhs.createdAt != rhs.createdAt {
            return lhs.createdAt > rhs.createdAt
        }
        return lhs.id.uuidString < rhs.id.uuidString
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
        amount: 40,
        billingCycle: .monthly,
        createdAt: Date(timeIntervalSince1970: 1_749_000_000),
        id: UUID(1),
        isActive: true,
        name: "Gym"
    )

    static let phonePlan = Expense(
        amount: 13,
        billingCycle: .monthly,
        createdAt: Date(timeIntervalSince1970: 1_748_000_000),
        id: UUID(2),
        isActive: false,
        name: "Phone Plan"
    )

    static let mocks: [Expense] = [.rent, .gym, .phonePlan]
}
