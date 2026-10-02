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
        let listedExpenses = store.listedExpenses
        NavigationStack(path: $store.scope(state: \.path, action: \.path)) {
            ScrollView {
                LazyVStack(spacing: 16) {
                    ForEach(listedExpenses) { $expense in
                        NavigationLink(state: ExpenseDetail.State(expense: $expense)) {
                            ExpenseCardView(expense: expense)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
            }
            .scrollIndicators(.hidden)
            .groupedBackground()
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
