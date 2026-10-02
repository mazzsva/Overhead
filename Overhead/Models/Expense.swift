//
//  Expense.swift
//  Overhead
//
//  Created by Lorenzo Mazzarotto on 13/07/26.
//

import Dependencies
import Foundation

struct Expense: Equatable, Identifiable, Sendable {
    let createdAt: Date
    var definition: String
    let id: UUID
    var term: String
}

extension Expense {
    static let blueMoon = Expense(
        createdAt: Date(timeIntervalSince1970: 1_750_000_000),
        definition: "Something that happens very rarely.",
        id: UUID(0),
        term: "Once in a blue moon"
    )

    static let burningCandle = Expense(
        createdAt: Date(timeIntervalSince1970: 1_749_000_000),
        definition: "To work early and late until you're exhausted.",
        id: UUID(1),
        term: "Burn the candle at both ends"
    )

    static let lowHangingFruit = Expense(
        createdAt: Date(timeIntervalSince1970: 1_748_000_000),
        definition: "The easiest wins, taken first.",
        id: UUID(2),
        term: "Low-hanging fruit"
    )

    static let mocks: [Expense] = [.blueMoon, .burningCandle, .lowHangingFruit]
}
