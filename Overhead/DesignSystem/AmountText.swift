//
//  AmountText.swift
//  Overhead
//
//  Created by Lorenzo Mazzarotto on 11/10/26.
//

import SwiftUI

struct AmountText: View {
    let value: Int
    let currency: Currency
    let isHidden: Bool

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Group {
            if isHidden {
                Text(Self.placeholder, format: .currency(currency))
                    .privacySensitive()
                    .redacted(reason: .privacy)
                    .accessibilityLabel(Text("Hidden"))
            } else {
                Text(value, format: .currency(currency))
            }
        }
        .transition(.replace(reducingMotion: reduceMotion))
    }

    private static let placeholder = 8_888
}

struct AmountLabel: View {
    let value: Int
    let currency: Currency
    let isHidden: Bool

    var body: some View {
        AmountText(value: value, currency: currency, isHidden: isHidden)
            .monospacedDigit()
            .contentTransition(.numericText(value: Double(value)))
            .lineLimit(1)
            .minimumScaleFactor(0.6)
    }
}
