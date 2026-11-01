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

    @State private var size: CGSize = .zero

    var body: some View {
        Group {
            if isHidden {
                Text(Self.placeholder, format: .currency(currency))
                    .hidden()
                    .overlay { blob }
                    .privacySensitive()
                    .allowsHitTesting(false)
                    .accessibilityLabel(Text("Hidden"))
            } else {
                Text(value, format: .currency(currency))
            }
        }
        .onGeometryChange(for: CGSize.self) {
            $0.size
        } action: {
            size = $0
        }
        .transaction(value: isHidden) { $0.animation = nil }
    }

    private var blob: some View {
        Capsule()
            .fill(.foreground)
            .opacity(Self.blobOpacity)
            .padding(.horizontal, size.height * Self.horizontalInsetRatio)
            .padding(.vertical, size.height * Self.verticalInsetRatio)
            .blur(radius: size.height * Self.blurRatio)
    }

    private static let blobOpacity = 0.4
    private static let blurRatio: CGFloat = 0.22
    private static let horizontalInsetRatio: CGFloat = 0.2
    private static let verticalInsetRatio: CGFloat = 0.2

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

#Preview {
    VStack(spacing: 24) {
        ForEach([false, true], id: \.self) { isHidden in
            VStack(spacing: 12) {
                AmountLabel(value: 464, currency: .eur, isHidden: isHidden)
                    .font(.system(size: 52, weight: .bold, design: .rounded))
                AmountLabel(value: 1_200, currency: .eur, isHidden: isHidden)
                    .font(.title2.bold())
                AmountLabel(value: 22, currency: .eur, isHidden: isHidden)
                    .font(.body)
            }
        }
    }
    .padding(32)
    .background(.orange.gradient)
}
