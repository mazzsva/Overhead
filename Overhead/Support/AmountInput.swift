//
//  AmountInput.swift
//  Overhead
//
//  Created by Lorenzo Mazzarotto on 12/10/26.
//

import Foundation
import RegexBuilder

enum AmountInput: Equatable {
    case empty
    case incomplete
    case overLimit(Amount)
    case refused
    case valid(Amount)

    init(text: String, locale: Locale, limit: Amount = .maximum) {
        let text = text.trimmingCharacters(in: .whitespacesAndNewlines)
        let number = Regex { Capture { IntegerFormatStyle<Int>(locale: locale) } }
        if text.isEmpty {
            self = .empty
        } else if text.contains(where: \.isLetter) || text.contains(locale.decimalSeparator ?? ".") {
            self = .refused
        } else if let value = text.wholeMatch(of: number)?.output.1 {
            if let amount = Amount(value: value) {
                self = amount > limit ? .overLimit(amount) : .valid(amount)
            } else {
                self = (0 ..< Amount.range.lowerBound).contains(value) ? .incomplete : .refused
            }
        } else {
            self = .refused
        }
    }

    var amount: Amount? {
        guard case .valid(let amount) = self else { return nil }
        return amount
    }

    var isInvalid: Bool {
        self != .empty && amount == nil
    }

    var isRefused: Bool {
        switch self {
        case .overLimit, .refused: true
        case .empty, .incomplete, .valid: false
        }
    }
}

extension Amount {
    func text(locale: Locale) -> String {
        value.formatted(.number.grouping(.never).locale(locale))
    }
}
