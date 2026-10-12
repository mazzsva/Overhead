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
        NavigationStack {
            AmountEntry(
                glow: Gradient(stops: [
                    .init(color: .orange, location: 0),
                    .init(color: .clear, location: 0.3),
                    .init(color: .green, location: 0.5),
                    .init(color: .clear, location: 0.7),
                    .init(color: .blue, location: 1),
                ])
            ) {
                AmountField(
                    title: "Income",
                    text: $store.incomeText,
                    currency: store.currency,
                    locale: store.locale,
                    isRefused: store.isIncomeRefused,
                    focus: $focus,
                    field: .income
                )
                caption
            } accessory: {
                if store.isEditing {
                    Button("Remove Income", role: .destructive) {
                        store.send(.removeButtonTapped)
                    }
                    .buttonStyle(.borderless)
                    .frame(minHeight: 44)
                }
            }
            .navigationTitle("Income")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save", systemImage: "checkmark") {
                        store.send(.saveButtonTapped)
                    }
                    .labelStyle(.iconOnly)
                    .disabled(store.income == nil)
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
            if store.isBelowInvestment, let investment = store.investment {
                Label {
                    Text(
                        "Your savings of \(Text(investment.value, format: .currency(store.currency).locale(store.locale))) will be removed."
                    )
                } icon: {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(.orange)
                }
            } else if store.isIncomeRefused {
                Text("Enter a valid amount.")
                    .foregroundStyle(.red)
            } else {
                Text("Your monthly pay after tax.")
                    .foregroundStyle(.secondary)
            }
        }
        .font(.callout)
        .multilineTextAlignment(.center)
        .animation(reduceMotion ? nil : .snappy, value: store.isBelowInvestment)
        .animation(reduceMotion ? nil : .snappy, value: store.isIncomeRefused)
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
