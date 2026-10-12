//
//  InvestmentFormView.swift
//  Overhead
//
//  Created by Lorenzo Mazzarotto on 04/10/26.
//

import ComposableArchitecture
import SwiftUI

struct InvestmentFormView: View {
    @Bindable var store: StoreOf<InvestmentForm>

    @FocusState private var focus: InvestmentForm.Field?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        NavigationStack {
            AmountEntry(glow: Gradient(colors: [.blue, .cyan, .blue])) {
                AmountField(
                    title: "Savings",
                    text: $store.investmentText,
                    currency: store.currency,
                    locale: store.locale,
                    isRefused: store.isInvestmentRefused,
                    focus: $focus,
                    field: .investment
                )
                caption
            } accessory: {
                shareButtons
                if store.isEditing {
                    Button("Remove Savings", role: .destructive) {
                        store.send(.removeButtonTapped)
                    }
                    .buttonStyle(.borderless)
                    .frame(minHeight: 44)
                }
            }
            .navigationTitle("Savings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save", systemImage: "checkmark") {
                        store.send(.saveButtonTapped)
                    }
                    .labelStyle(.iconOnly)
                    .disabled(!store.isSubmittable)
                }
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", systemImage: "xmark") {
                        store.send(.dismissButtonTapped)
                    }
                    .confirmationDialog(
                        $store.scope(state: \.destination?.confirmationDialog, action: \.destination.confirmationDialog)
                    )
                    .foregroundStyle(.secondary)
                    .labelStyle(.iconOnly)
                }
            }
            .interactiveDismissDisabled(store.hasChanges)
            .bind($store.focus, to: $focus)
            .alert($store.scope(state: \.destination?.alert, action: \.destination.alert))
        }
        .environment(\.locale, store.locale)
    }

    private var caption: some View {
        Group {
            if store.exceedsIncome {
                Text("Your savings can't be more than your income.")
                    .foregroundStyle(.red)
            } else if store.isInvestmentRefused {
                Text("Enter a valid amount.")
                    .foregroundStyle(.red)
            } else if let share = store.share {
                Text(
                    "\(Text(share, format: .percent.precision(.fractionLength(0)))) of your \(Text(store.income.value, format: .currency(store.currency).locale(store.locale))) income."
                )
                .foregroundStyle(.secondary)
                .contentTransition(reduceMotion ? .opacity : .numericText(value: share.doubleValue))
            } else {
                Text("The amount you save or invest each month.")
                    .foregroundStyle(.secondary)
            }
        }
        .font(.callout)
        .multilineTextAlignment(.center)
        .animation(reduceMotion ? nil : .snappy, value: store.share)
        .animation(reduceMotion ? nil : .snappy, value: store.exceedsIncome)
        .animation(reduceMotion ? nil : .snappy, value: store.isInvestmentRefused)
    }

    private var shareButtons: some View {
        let layout =
            dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(spacing: 8))
            : AnyLayout(HStackLayout(spacing: 8))
        return layout {
            ForEach(store.shareOptions) { option in
                ShareButton(
                    amount: option.amount,
                    currency: store.currency,
                    isSelected: store.selectedSharePercent == option.percent,
                    locale: store.locale,
                    percent: option.percent
                ) {
                    store.send(.shareButtonTapped(option.percent), animation: reduceMotion ? nil : .snappy)
                }
            }
        }
        .sensoryFeedback(.selection, trigger: store.selectedSharePercent) { $1 != nil }
    }
}

private struct ShareButton: View {
    let amount: Amount?
    let currency: Currency
    let isSelected: Bool
    let locale: Locale
    let percent: Int
    let action: () -> Void

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        let share = Decimal(percent) / 100
        Button(action: action) {
            let layout =
                dynamicTypeSize.isAccessibilitySize
                ? AnyLayout(HStackLayout(alignment: .firstTextBaseline))
                : AnyLayout(VStackLayout(spacing: 2))
            layout {
                Text(share, format: .percent)
                    .font(.system(.headline, design: .rounded))
                if dynamicTypeSize.isAccessibilitySize {
                    Spacer(minLength: 8)
                }
                Text(amount?.value ?? 0, format: .currency(currency).locale(locale))
                    .font(.footnote)
                    .monospacedDigit()
                    .foregroundStyle(isSelected ? AnyShapeStyle(.white.opacity(0.85)) : AnyShapeStyle(.secondary))
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(ShareButtonStyle(isSelected: isSelected))
        .disabled(amount == nil)
        .accessibilityLabel(Text("Save \(Text(share, format: .percent)) of income"))
        .accessibilityValue(Text(amount?.value ?? 0, format: .currency(currency).locale(locale)))
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

private struct ShareButtonStyle: ButtonStyle {
    let isSelected: Bool

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(isSelected ? AnyShapeStyle(.white) : AnyShapeStyle(.primary))
            .padding(.horizontal, 12)
            .padding(.vertical, 12)
            .background(
                isSelected ? AnyShapeStyle(.blue) : AnyShapeStyle(Color(.secondarySystemGroupedBackground)),
                in: .rect(cornerRadius: 18, style: .continuous)
            )
            .contentShape(.rect(cornerRadius: 18, style: .continuous))
            .scaleEffect(configuration.isPressed && !reduceMotion ? 0.96 : 1)
            .animation(.snappy(duration: 0.2), value: configuration.isPressed)
            .animation(.snappy(duration: 0.25), value: isSelected)
    }
}

#Preview("Add") {
    InvestmentFormView(
        store: Store(initialState: InvestmentForm.State(income: 3000, investment: nil)) {
            InvestmentForm()
        }
    )
}

#Preview("Edit") {
    InvestmentFormView(
        store: Store(initialState: InvestmentForm.State(income: 3000, investment: 450)) {
            InvestmentForm()
        }
    )
}
