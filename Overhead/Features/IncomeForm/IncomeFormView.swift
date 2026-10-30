//
//  IncomeFormView.swift
//  Overhead
//
//  Created by Lorenzo Mazzarotto on 04/10/26.
//

import ComposableArchitecture
import SwiftUI

struct IncomeFormView: View {
    @Bindable var store: StoreOf<IncomeForm>

    @FocusState private var focus: IncomeForm.Field?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        EntrySheet(
            title: Text("Income"),
            accent: .income,
            canConfirm: store.isSubmittable,
            locale: store.income.locale,
            onCancellation: { store.send(.dismissButtonTapped) },
            onConfirmation: { store.send(.saveButtonTapped) }
        ) {
            AmountFieldView(
                store: store.scope(state: \.income, action: \.income),
                title: "Income",
                focus: $focus,
                field: .income
            )
            caption
        } accessory: {
            if store.isEditing {
                DestructiveButton(title: "Remove Income") {
                    store.send(.removeButtonTapped)
                }
            }
        }
        .bind($store.focus, to: $focus)
        .alert($store.scope(state: \.destination?.alert, action: \.destination.alert))
    }

    private var caption: some View {
        Group {
            if store.isBelowInvestment, let investment = store.investment {
                SheetCaption(
                    tone: .warning,
                    text: Text(
                        "Your savings of \(Text(investment.value, format: .currency(store.income.currency))) will be removed"
                    )
                )
            } else if store.income.input.isRefused {
                SheetCaption(tone: .error, text: Text("Enter a valid amount"))
            } else {
                SheetCaption(tone: .info, text: Text("Your monthly pay after tax"))
            }
        }
        .animation(.value(reducingMotion: reduceMotion), value: store.isBelowInvestment)
        .animation(.value(reducingMotion: reduceMotion), value: store.income.input.isRefused)
    }
}

#Preview("Add") {
    IncomeFormView(
        store: Store(initialState: IncomeForm.State(budget: nil)) {
            IncomeForm()
        }
    )
}

#Preview("Edit") {
    IncomeFormView(
        store: Store(initialState: IncomeForm.State(budget: .mock)) {
            IncomeForm()
        }
    )
}
