//
//  ExpenseName.swift
//  Overhead
//
//  Created by Lorenzo Mazzarotto on 12/10/26.
//

import Foundation

struct ExpenseName: Hashable, Sendable {
    static let maximumLength = 100

    let value: String

    init?(value text: String) {
        let text = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty, text.utf16.count <= Self.maximumLength else { return nil }
        value = text
    }
}

extension ExpenseName: ExpressibleByStringLiteral {
    init(stringLiteral value: String) {
        guard let name = ExpenseName(value: value) else {
            preconditionFailure("\"\(value)\" is not a valid expense name.")
        }
        self = name
    }
}
