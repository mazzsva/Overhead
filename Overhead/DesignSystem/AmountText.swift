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

    var body: some View {
        Text(value, format: .currency(currency))
    }
}

struct AmountLabel: View {
    let value: Int
    let currency: Currency

    var body: some View {
        AmountText(value: value, currency: currency)
            .monospacedDigit()
            .contentTransition(.numericText(value: Double(value)))
            .lineLimit(1)
            .minimumScaleFactor(0.6)
    }
}

#Preview {
    VStack(spacing: 12) {
        AmountLabel(value: 464, currency: .eur)
            .font(.system(size: 52, weight: .bold, design: .rounded))
        AmountLabel(value: 1_200, currency: .eur)
            .font(.title2.bold())
        AmountLabel(value: 22, currency: .eur)
            .font(.body)
    }
    .padding(32)
    .background(.orange.gradient)
}
