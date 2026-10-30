//
//  ChoiceButton.swift
//  Overhead
//
//  Created by Lorenzo Mazzarotto on 12/10/26.
//

import SwiftUI

struct ChoiceGroup<Content: View>: View {
    @ViewBuilder let content: Content

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        let layout =
            dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(spacing: 8))
            : AnyLayout(HStackLayout(spacing: 8))
        layout {
            content
        }
    }
}

struct ChoiceButton<Detail: View>: View {
    let title: Text
    let accent: Accent
    let isSelected: Bool
    let action: () -> Void
    @ViewBuilder let detail: Detail

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        Button(action: action) {
            let layout =
                dynamicTypeSize.isAccessibilitySize
                ? AnyLayout(HStackLayout(alignment: .firstTextBaseline))
                : AnyLayout(VStackLayout(spacing: 2))
            layout {
                title
                    .font(.system(.headline, design: .rounded))
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                if dynamicTypeSize.isAccessibilitySize {
                    Spacer(minLength: 8)
                }
                detail
                    .font(.footnote)
                    .monospacedDigit()
                    .foregroundStyle(isSelected ? AnyShapeStyle(.white.opacity(0.9)) : AnyShapeStyle(.secondary))
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(ChoiceButtonStyle(accent: accent, isSelected: isSelected))
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

private struct ChoiceButtonStyle: ButtonStyle {
    let accent: Accent
    let isSelected: Bool

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        let shape = CornerRadius.control.shape
        configuration.label
            .foregroundStyle(isSelected ? AnyShapeStyle(.white) : AnyShapeStyle(.primary))
            .padding(12)
            .background {
                shape.fill(Color(.secondarySystemGroupedBackground))
                shape.fill(accent.fill).opacity(isSelected ? 1 : 0)
            }
            .contentShape(shape)
            .opacity(isEnabled ? 1 : 0.5)
            .scaleEffect(configuration.isPressed && !reduceMotion ? 0.96 : 1)
            .animation(.press, value: configuration.isPressed)
            .animation(.selection(reducingMotion: reduceMotion), value: isSelected)
    }
}
