//
//  ExpensesView.swift
//  Overhead
//
//  Created by Lorenzo Mazzarotto on 24/07/26.
//

import ComposableArchitecture
import SwiftUI

struct ExpensesView: View {
    @Bindable var store: StoreOf<Expenses>

    var body: some View {
        let activeExpenses = store.activeExpenses
        let inactiveExpenses = store.inactiveExpenses
        NavigationStack(path: $store.scope(state: \.path, action: \.path)) {
            List {
                if !activeExpenses.isEmpty {
                    Section {
                        ForEach(activeExpenses) { expense in
                            row(expense)
                        }
                    }
                }
                if !inactiveExpenses.isEmpty {
                    Section("Inactive") {
                        ForEach(inactiveExpenses) { expense in
                            row(expense)
                        }
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .groupedBackground()
            .contentMargins(.top, 8, for: .scrollContent)
            .navigationBarTitleDisplayMode(.inline)
            .toolbarRole(.editor)
            .toolbar {
                ToolbarItem(placement: .title) {
                    Text("Expenses")
                        .font(.title)
                        .fontWeight(.bold)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("New Expense", systemImage: "plus") {
                        store.send(.newExpenseButtonTapped)
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
            .overlay {
                if store.isEmpty {
                    ContentUnavailableView(
                        "No Expenses",
                        systemImage: "tray.fill",
                        description: Text("Tap the plus button to add an expense.")
                    )
                }
            }
        } destination: { detailStore in
            ExpenseDetailView(store: detailStore)
        }
        .sheet(
            item: $store.scope(state: \.destination?.createExpense, action: \.destination.createExpense)
        ) { formStore in
            ExpenseFormView(store: formStore)
        }
    }

    private func row(_ expense: Expense) -> some View {
        Button {
            store.send(.expenseCardTapped(expense.id))
        } label: {
            ExpenseRowView(expense: expense)
        }
        .tint(.primary)
    }
}

#Preview("Populated") {
    let store = Store(initialState: Expenses.State(user: .mock)) {
        Expenses()
    }
    ExpensesView(store: store)
        .task { await store.send(.task).finish() }
}

#Preview("Empty") {
    let store = Store(initialState: Expenses.State(user: .mock)) {
        Expenses()
    } withDependencies: {
        $0.expensesClient.expenses = { _ in
            AsyncThrowingStream { continuation in
                continuation.yield([])
            }
        }
    }
    ExpensesView(store: store)
        .task { await store.send(.task).finish() }
}
