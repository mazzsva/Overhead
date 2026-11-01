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
        EntrySheet(
            title: title,
            accent: accent,
            canConfirm: store.isSubmittable,
            locale: store.amount.locale,
            onCancellation: { store.send(.dismissButtonTapped) },
            onConfirmation: { store.send(.saveButtonTapped) }
        ) {
            AmountFieldView(
                store: store.scope(state: \.amount, action: \.amount),
                title: "Amount",
                focus: $focus,
                field: .amount
            )
            Picker("Billing Cycle", selection: $store.billingCycle.sending(\.billingCycleButtonTapped)) {
                ForEach(BillingCycle.allCases, id: \.self) { billingCycle in
                    Text(billingCycle.title)
                }
            }
            .pickerStyle(.segmented)
            .controlSize(.extraLarge)
            .padding(.top, 14)
            .sensoryFeedback(.selection, trigger: store.billingCycle)
            NameFieldView(
                store: store.scope(state: \.name, action: \.name),
                title: "Title",
                focus: $focus,
                field: .name,
                submitLabel: store.amount.value == nil ? .next : .done,
                onSubmit: { store.send(.nameFieldSubmitted) }
            )
            .padding(.top, 36)
        } accessory: {
        }
        .bind($store.focus, to: $focus)
    }

    private var accent: Accent {
        .expense(isActive: store.isActive)
    }

    private var title: Text {
        store.isCreating ? Text("New Expense") : Text("Edit Expense")
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
