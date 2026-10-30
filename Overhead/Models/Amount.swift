//
//  Amount.swift
//  Overhead
//
//  Created by Lorenzo Mazzarotto on 12/10/26.
//

import Foundation

struct Amount: Comparable, Hashable, Sendable {
    static let range = 1 ... 999_999_999
    static let maximum = Amount(validValue: range.upperBound)

    let value: Int

    init?(value: Int) {
        guard Self.range.contains(value) else { return nil }
        self.init(validValue: value)
    }

    private init(validValue value: Int) {
        self.value = value
    }

    static func < (lhs: Self, rhs: Self) -> Bool {
        lhs.value < rhs.value
    }
}

extension Amount: ExpressibleByIntegerLiteral {
    init(integerLiteral value: Int) {
        guard let amount = Amount(value: value) else { preconditionFailure("\(value) is not a valid amount.") }
        self = amount
    }
}
