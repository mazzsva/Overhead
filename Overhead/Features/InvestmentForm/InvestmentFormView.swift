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

    var body: some View {
        EntrySheet(
            title: Text("Savings"),
            accent: .savings,
            canConfirm: store.isSubmittable,
            locale: store.investment.locale,
            onCancellation: { store.send(.dismissButtonTapped) },
            onConfirmation: { store.send(.saveButtonTapped) }
        ) {
            AmountFieldView(
                store: store.scope(state: \.investment, action: \.investment),
                title: "Savings",
                focus: $focus,
                field: .investment
            )
            caption
        } accessory: {
            shareChoices
            if store.isEditing {
                DestructiveButton(title: "Remove Savings") {
                    store.send(.removeButtonTapped)
                }
            }
        }
        .bind($store.focus, to: $focus)
        .alert($store.scope(state: \.destination?.alert, action: \.destination.alert))
    }

    private var caption: some View {
        let currency = store.investment.currency
        return Group {
            if store.exceedsIncome {
                SheetCaption(tone: .error, text: Text("Your savings can't be more than your income"))
            } else if store.investment.input.isRefused {
                SheetCaption(tone: .error, text: Text("Enter a valid amount"))
            } else if let share = store.share {
                SheetCaption(
                    tone: .info,
                    text: Text(
                        "\(Text(share, format: .percent.precision(.fractionLength(0)))) of your \(Text(store.income.value, format: .currency(currency))) income"
                    )
                )
                .contentTransition(reduceMotion ? .opacity : .numericText(value: share.doubleValue))
            } else {
                SheetCaption(tone: .info, text: Text("The amount you save or invest each month"))
            }
        }
        .animation(.value(reducingMotion: reduceMotion), value: store.share)
        .animation(.value(reducingMotion: reduceMotion), value: store.exceedsIncome)
        .animation(.value(reducingMotion: reduceMotion), value: store.investment.input.isRefused)
    }

    private var shareChoices: some View {
        let currency = store.investment.currency
        return ChoiceGroup {
            ForEach(store.shareOptions) { option in
                let share = Decimal(option.percent) / 100
                let amount = Text(option.amount?.value ?? 0, format: .currency(currency))
                ChoiceButton(
                    title: Text(share, format: .percent),
                    accent: .savings,
                    isSelected: store.selectedSharePercent == option.percent
                ) {
                    store.send(.shareButtonTapped(option.percent), animation: .selection(reducingMotion: reduceMotion))
                } detail: {
                    amount
                }
                .disabled(option.amount == nil)
                .accessibilityLabel(Text("Save \(Text(share, format: .percent)) of income"))
                .accessibilityValue(amount)
            }
        }
        .sensoryFeedback(.selection, trigger: store.selectedSharePercent) { $1 != nil }
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
