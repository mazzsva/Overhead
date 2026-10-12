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
        .transition(reduceMotion ? .opacity : AnyTransition(.blurReplace))
    }

    private static let placeholder = 8_888
}
