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

    @FocusState private var isNameFocused: Bool

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Name", text: $store.name)
                        .focused($isNameFocused)
                }
                Section {
                    TextField(
                        "Amount",
                        text: $store.amountText,
                        prompt: Text(Decimal.zero, format: .currency(code: store.currencyCode).locale(store.locale))
                    )
                    .keyboardType(.decimalPad)
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
            .onAppear { appeared() }
        }
    }

    private func appeared() {
        guard store.isCreating else { return }
        isNameFocused = true
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
