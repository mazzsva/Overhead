//
//  PressableButtonStyle.swift
//  Overhead
//
//  Created by Lorenzo Mazzarotto on 12/10/26.
//

import SwiftUI

struct PressableButtonStyle: ButtonStyle {
    let radius: CornerRadius

    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(.primary)
            .contentShape(radius.shape)
            .brightness(configuration.isPressed ? (colorScheme == .dark ? 0.04 : -0.03) : 0)
            .scaleEffect(configuration.isPressed && !reduceMotion ? 0.97 : 1)
            .animation(.press, value: configuration.isPressed)
    }
}

extension ButtonStyle where Self == PressableButtonStyle {
    static func pressable(_ radius: CornerRadius) -> Self {
        PressableButtonStyle(radius: radius)
    }
}
