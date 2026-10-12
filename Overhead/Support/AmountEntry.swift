//
//  AmountEntry.swift
//  Overhead
//
//  Created by Lorenzo Mazzarotto on 12/10/26.
//

import SwiftUI

struct AmountEntry<Content: View, Accessory: View>: View {
    let glow: Gradient
    @ViewBuilder let content: Content
    @ViewBuilder let accessory: Accessory

    var body: some View {
        GeometryReader { proxy in
            ScrollView {
                VStack(spacing: 24) {
                    Spacer(minLength: 0)
                    VStack(spacing: 10) {
                        content
                    }
                    Spacer(minLength: 0)
                    Spacer(minLength: 0)
                    VStack(spacing: 12) {
                        accessory
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
                .frame(maxWidth: .infinity, minHeight: proxy.size.height)
            }
            .scrollBounceBehavior(.basedOnSize)
        }
        .background {
            AmountEntryGlow(gradient: glow)
        }
    }
}

struct AmountField<Field: Hashable & Sendable>: View {
    let title: LocalizedStringKey
    @Binding var text: String
    let currency: Currency
    let locale: Locale
    let isRefused: Bool
    let focus: FocusState<Field?>.Binding
    let field: Field

    @ScaledMetric(relativeTo: .largeTitle) private var fontSize = 64
    @State private var refusals = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Text(currency.displayText(amountText: text, locale: locale))
            .font(font)
            .kerning(-1.1)
            .monospacedDigit()
            .foregroundStyle(foregroundStyle)
            .lineLimit(1)
            .minimumScaleFactor(0.3)
            .contentTransition(reduceMotion ? .opacity : .numericText())
            .animation(reduceMotion ? nil : .snappy(duration: 0.3), value: text)
            .animation(.easeInOut(duration: 0.2), value: isRefused)
            .frame(maxWidth: .infinity)
            .contentShape(.rect)
            .onTapGesture { focus.wrappedValue = field }
            .accessibilityHidden(true)
            .overlay {
                TextField(title, text: $text, prompt: Text(verbatim: ""))
                    .font(font)
                    .kerning(-1.1)
                    .multilineTextAlignment(.center)
                    .keyboardType(.decimalPad)
                    .foregroundStyle(.clear)
                    .tint(.clear)
                    .focused(focus, equals: field)
                    .allowsHitTesting(false)
                    .accessibilityValue(Text(verbatim: currency.displayText(amountText: text, locale: locale)))
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

    private func isRefusedChanged(_ isRefused: Bool) {
        guard isRefused, !reduceMotion else { return }
        refusals += 1
    }

    private var font: Font {
        .system(size: min(fontSize, 104), weight: .bold, design: .rounded)
    }

    private var foregroundStyle: AnyShapeStyle {
        if isRefused {
            AnyShapeStyle(.red)
        } else if text.isEmpty {
            AnyShapeStyle(.tertiary)
        } else {
            AnyShapeStyle(.primary)
        }
    }
}

private struct AmountEntryGlow: View {
    let gradient: Gradient

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        Color(.systemGroupedBackground)
            .overlay(alignment: .top) {
                LinearGradient(gradient: gradient, startPoint: .leading, endPoint: .trailing)
                    .frame(height: 340)
                    .mask {
                        LinearGradient(
                            colors: [.black, .black.opacity(0.4), .clear], startPoint: .top, endPoint: .bottom)
                    }
                    .blur(radius: 48)
                    .opacity(colorScheme == .dark ? 0.3 : 0.24)
            }
            .ignoresSafeArea()
            .accessibilityHidden(true)
    }
}
