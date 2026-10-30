//
//  ExpenseNameInput.swift
//  Overhead
//
//  Created by Lorenzo Mazzarotto on 12/10/26.
//

import Foundation

enum ExpenseNameInput: Equatable {
    case empty
    case tooLong
    case valid(ExpenseName)

    init(text: String) {
        if let name = ExpenseName(value: text) {
            self = .valid(name)
        } else if text.allSatisfy(\.isWhitespace) {
            self = .empty
        } else {
            self = .tooLong
        }
    }

    var isInvalid: Bool {
        self == .tooLong
    }

    var name: ExpenseName? {
        guard case .valid(let name) = self else { return nil }
        return name
    }
}
