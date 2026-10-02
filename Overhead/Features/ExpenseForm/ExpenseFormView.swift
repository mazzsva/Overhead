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

    @FocusState private var isTermFocused: Bool

    var body: some View {
        NavigationStack {
            Form {
                Section("Term") {
                    TextField("", text: $store.term)
                        .focused($isTermFocused)
                        .accessibilityLabel("Term")
                }
                Section("Definition") {
                    TextEditor(text: $store.definition)
                        .frame(minHeight: 180)
                        .accessibilityLabel("Definition")
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
        isTermFocused = true
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
        store: Store(initialState: ExpenseForm.State(expense: .blueMoon)) {
            ExpenseForm()
        }
    )
}
