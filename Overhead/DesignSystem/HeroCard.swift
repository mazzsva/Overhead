//
//  HeroCard.swift
//  Overhead
//
//  Created by Lorenzo Mazzarotto on 12/10/26.
//

import SwiftUI

enum HeroGlow: Equatable {
    case accent(Accent)
    case breakdown(available: Double, expenses: Double, savings: Double)
}

struct HeroCard<Value: View, Caption: View>: View {
    let title: LocalizedStringResource
    let glow: HeroGlow
    let accessibilityValue: Text
    var hasCard = true
    @ViewBuilder let value: Value
    @ViewBuilder let caption: Caption

    @ScaledMetric(relativeTo: .largeTitle) private var cardValueSize = 48
    @ScaledMetric(relativeTo: .largeTitle) private var plainValueSize = 58

    private var valueSize: CGFloat { hasCard ? cardValueSize : plainValueSize }
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(spacing: 0) {
            Text(title)
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundStyle(.secondary)
                .contentTransition(.interpolate)
                .accessibilityHidden(true)

            value
                .font(.system(size: valueSize, weight: .bold, design: .rounded))
                .kerning(-0.8)
                .padding(.top, 2)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(Text(title))
                .accessibilityValue(accessibilityValue)

            caption
                .font(.footnote)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 20)
        .padding(.top, hasCard ? 20 : 28)
        .padding(.bottom, hasCard ? 22 : 24)
        .background {
            if hasCard {
                HeroBackground(glow: glow)
                    .animation(.glow(reducingMotion: reduceMotion), value: glow)
            }
        }
    }
}

private struct HeroBackground: View {
    let glow: HeroGlow

    var body: some View {
        let shape = CornerRadius.hero.shape
        shape
            .fill(
                LinearGradient(
                    colors: [Color(white: 0.17), Color(white: 0.12), Color(white: 0.1)],
                    startPoint: UnitPoint(x: 0.35, y: 0),
                    endPoint: UnitPoint(x: 0.65, y: 1)
                )
            )
            .overlay(alignment: .top) {
                ZStack {
                    Ellipse()
                        .fill(Accent.expenses.color.opacity(opacity(for: share(of: .expenses))))
                        .frame(width: 240, height: 180)
                        .offset(x: -150)
                    Ellipse()
                        .fill(Accent.available.color.opacity(opacity(for: share(of: .available))))
                        .frame(width: 200, height: 190)
                        .offset(y: -60)
                    Ellipse()
                        .fill(Accent.savings.color.opacity(opacity(for: share(of: .savings))))
                        .frame(width: 260, height: 190)
                        .offset(x: 150)
                    Ellipse()
                        .fill(accentColor.opacity(accentColor == .clear ? 0 : opacity(for: 1)))
                        .frame(width: 460, height: 200)
                        .offset(y: -40)
                }
                .offset(y: -110)
                .blur(radius: 36)
                .allowsHitTesting(false)
                .accessibilityHidden(true)
            }
            .clipShape(shape)
            .overlay {
                shape.stroke(.primary.opacity(0.1), lineWidth: 0.5)
            }
    }

    private var accentColor: Color {
        guard case .accent(let accent) = glow else { return .clear }
        return accent.color
    }

    private func share(of accent: Accent) -> Double {
        guard case .breakdown(let available, let expenses, let savings) = glow else { return 0 }
        switch accent {
        case .available: return available
        case .expenses: return expenses
        case .savings: return savings
        case .income, .neutral, .overIncome: return 0
        }
    }

    private func opacity(for share: Double) -> Double {
        guard share > 0 else { return 0 }
        return (0.06 + 0.16 * min(share, 1)) * 1.15
    }
}
