//
//  OpenEntry.swift
//  Overhead
//
//  Created by Lorenzo Mazzarotto on 13/10/26.
//

import SwiftUI

struct OpenEntry<Field: Hashable & Sendable>: View {
    enum Style {
        case amount
        case text

        fileprivate var baseSize: CGFloat {
            switch self {
            case .amount: 64
            case .text: 46
            }
        }

        fileprivate var lineLimit: Int {
            switch self {
            case .amount: 1
            case .text: 2
            }
        }

        fileprivate var maximumSize: CGFloat {
            switch self {
            case .amount: 104
            case .text: 80
            }
        }

        fileprivate var minimumScaleFactor: CGFloat {
            switch self {
            case .amount: 0.3
            case .text: 0.5
            }
        }
    }

    let style: Style
    let title: LocalizedStringResource
    let display: Text
    let isPlaceholder: Bool
    let isRefused: Bool
    @Binding var text: String
    let focus: FocusState<Field?>.Binding
    let field: Field
    var accessibilityValue: Text?
    var placeholder: Text?
    var onSubmit: () -> Void = {}

    @ScaledMetric(relativeTo: .largeTitle) private var scale = 1
    @State private var refusals = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack {
            if isPlaceholder, let placeholder {
                placeholder
                    .foregroundStyle(.tertiary)
                    .transition(
                        .asymmetric(
                            insertion: .opacity.animation(.easeOut(duration: 0.14).delay(0.05)),
                            removal: .identity
                        )
                    )
            } else {
                display
                    .foregroundStyle(foregroundStyle)
                    .contentTransition(reduceMotion ? .opacity : .numericText())
                    .animation(reduceMotion ? nil : .typing, value: text)
                    .animation(.fade, value: isRefused)
                    .transition(
                        reduceMotion
                            ? .opacity
                            : .asymmetric(
                                insertion: AnyTransition(.blurReplace(.downUp)),
                                removal: AnyTransition(.blurReplace(.upUp))
                            )
                    )
            }
        }
        .animation(.typing(reducingMotion: reduceMotion), value: isPlaceholder)
        .font(font)
        .kerning(-1.1)
        .monospacedDigit()
        .lineLimit(style.lineLimit)
        .multilineTextAlignment(.center)
        .minimumScaleFactor(style.minimumScaleFactor)
        .frame(maxWidth: .infinity)
        .contentShape(.rect)
        .onTapGesture { focus.wrappedValue = field }
        .accessibilityHidden(true)
        .overlay {
            TextField(text: $text, prompt: Text(verbatim: "")) {
                Text(title)
            }
            .font(font)
            .multilineTextAlignment(.center)
            .keyboardType(style == .amount ? .numberPad : .default)
            .textInputAutocapitalization(style == .amount ? .never : .words)
            .autocorrectionDisabled()
            .submitLabel(.next)
            .onSubmit(onSubmit)
            .foregroundStyle(.clear)
            .tint(.clear)
            .focused(focus, equals: field)
            .allowsHitTesting(false)
            .accessibilityValue(accessibilityValue ?? Text(verbatim: text))
        }
        .keyframeAnimator(initialValue: 0.0, trigger: refusals) { content, offset in
            content.offset(x: offset)
        } keyframes: { _ in
            KeyframeTrack {
                LinearKeyframe(-10, duration: 0.06)
                LinearKeyframe(8, duration: 0.08)
                LinearKeyframe(-5, duration: 0.08)
                LinearKeyframe(3, duration: 0.07)
                LinearKeyframe(0, duration: 0.06)
            }
        }
        .sensoryFeedback(.error, trigger: isRefused) { !$0 && $1 }
        .onChange(of: isRefused) { isRefusedChanged($1) }
    }

    private var font: Font {
        .system(size: min(style.baseSize * scale, style.maximumSize), weight: .bold, design: .rounded)
    }

    private var foregroundStyle: AnyShapeStyle {
        if isRefused {
            AnyShapeStyle(Color.critical)
        } else if isPlaceholder {
            AnyShapeStyle(.tertiary)
        } else {
            AnyShapeStyle(.primary)
        }
    }

    private func isRefusedChanged(_ isRefused: Bool) {
        guard isRefused, !reduceMotion else { return }
        refusals += 1
    }
}
