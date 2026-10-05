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

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField(
                        "Income",
                        text: $store.incomeText,
                        prompt: Text(Decimal.zero, format: .dollars.locale(store.locale))
                    )
                    .keyboardType(.decimalPad)
                    .focused($focus, equals: .income)
                } footer: {
                    if store.isBelowInvestment, let investment = store.investment {
                        Text(
                            "Saving will remove your investments of \(Text(investment, format: .dollars.locale(store.locale)))."
                        )
                    } else if store.isIncomeInvalid {
                        Text("Enter a valid amount.")
                    } else {
                        Text("Your monthly pay after tax.")
                    }
                }
                if store.isEditing {
                    Section {
                        Button("Remove Income", role: .destructive) {
                            store.send(.removeButtonTapped)
                        }
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .groupedBackground()
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
