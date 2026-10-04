//
//  ExpenseFormView.swift
//  Overhead
//
//  Created by Lorenzo Mazzarotto on 20/07/26.
//

import ComposableArchitecture
import SwiftUI

struct ExpenseFormView: View {
    @Bindable var store: StoreOf<ExpenseForm>

    @FocusState private var focus: ExpenseForm.Field?

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Name", text: $store.name)
                        .focused($focus, equals: .name)
                }
                Section {
                    TextField(
                        "Amount",
                        text: $store.amountText,
                        prompt: Text(Decimal.zero, format: .dollars.locale(store.locale))
                    )
                    .keyboardType(.decimalPad)
                }
                Section("Billing Cycle") {
                    Picker("Billing Cycle", selection: $store.billingCycle) {
                        ForEach(BillingCycle.allCases, id: \.self) { billingCycle in
                            Text(billingCycle.title)
                                .tag(billingCycle)
                        }
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets())
                }
                if !store.isCreating {
                    Section {
                        Toggle("Active", isOn: $store.isActive)
                    } footer: {
                        Text("An inactive expense stays in your list, so you can resume it later.")
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .groupedBackground()
            .navigationTitle(store.isCreating ? "New Expense" : "Edit Expense")
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
                    Button("Dismiss", systemImage: "xmark") {
                        store.send(.dismissButtonTapped)
                    }
                    .foregroundStyle(.secondary)
                    .labelStyle(.iconOnly)
                }
            }
            .interactiveDismissDisabled(store.hasChanges)
            .bind($store.focus, to: $focus)
            .alert($store.scope(state: \.alert, action: \.alert))
        }
    }
}

#Preview("Create") {
    ExpenseFormView(
        store: Store(initialState: ExpenseForm.State()) {
            ExpenseForm()
        }
    )
}

#Preview("Edit") {
    ExpenseFormView(
        store: Store(initialState: ExpenseForm.State(expense: .gym)) {
            ExpenseForm()
        }
    )
}
