//
//  ExpenseDetailView.swift
//  Overhead
//
//  Created by Lorenzo Mazzarotto on 24/07/26.
//

import ComposableArchitecture
import SwiftUI

struct ExpenseDetailView: View {
    @Bindable var store: StoreOf<ExpenseDetail>

    var body: some View {
        List {
            Section {
                LabeledContent(
                    "Amount",
                    value: store.expense.amount,
                    format: .currency(code: store.expense.currencyCode)
                )
            }
            Section {
                Button("Delete Expense", role: .destructive) {
                    store.send(.deleteButtonTapped)
                }
            }
        }
        .scrollContentBackground(.hidden)
        .groupedBackground()
        .navigationTitle(store.expense.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Edit") {
                    store.send(.editButtonTapped)
                }
            }
        }
        .alert($store.scope(state: \.destination?.alert, action: \.destination.alert))
        .sheet(
            item: $store.scope(state: \.destination?.editExpense, action: \.destination.editExpense)
        ) { formStore in
            ExpenseFormView(store: formStore)
        }
    }
}

#Preview {
    NavigationStack {
        ExpenseDetailView(
            store: Store(initialState: ExpenseDetail.State(expense: SharedReader(value: .gym))) {
                ExpenseDetail()
            }
        )
    }
}
