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
    @State private var height: CGFloat = 0

    var body: some View {
        Group {
            if isHidden {
                Text(Self.placeholder, format: .currency(currency))
                    .privacySensitive()
                    .blur(radius: height * Self.blurRatio)
                    .allowsHitTesting(false)
                    .accessibilityLabel(Text("Hidden"))
            } else {
                Text(value, format: .currency(currency))
            }
        }
        .onGeometryChange(for: CGFloat.self) {
            $0.size.height
        } action: {
            height = $0
        }
        .transition(.replace(reducingMotion: reduceMotion))
    }

    private static let blurRatio: CGFloat = 0.3

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
