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
    var currencyCode: String
    let id: UUID
    var isActive: Bool
    var name: String
}

extension Expense {
    static let rent = Expense(
        amount: 950,
        billingCycle: .monthly,
        createdAt: Date(timeIntervalSince1970: 1_750_000_000),
        currencyCode: "EUR",
        id: UUID(0),
        isActive: true,
        name: "Rent"
    )

    static let gym = Expense(
        amount: Decimal(minorUnits: 3990, currencyCode: "EUR"),
        billingCycle: .monthly,
        createdAt: Date(timeIntervalSince1970: 1_749_000_000),
        currencyCode: "EUR",
        id: UUID(1),
        isActive: true,
        name: "Gym"
    )

    static let phonePlan = Expense(
        amount: Decimal(minorUnits: 1299, currencyCode: "EUR"),
        billingCycle: .monthly,
        createdAt: Date(timeIntervalSince1970: 1_748_000_000),
        currencyCode: "EUR",
        id: UUID(2),
        isActive: false,
        name: "Phone Plan"
    )

    static let mocks: [Expense] = [.rent, .gym, .phonePlan]
}
