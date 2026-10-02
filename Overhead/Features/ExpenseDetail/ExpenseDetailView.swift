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
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text(store.expense.term)
                    .font(.title2)
                    .fontWeight(.semibold)

                if !store.expense.definition.isEmpty {
                    Text(store.expense.definition)
                }

                Text("Created \(store.expense.createdAt.formatted(date: .abbreviated, time: .shortened))")
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundStyle(.secondary)
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .groupedBackground()
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button(
                    store.expense.isBookmarked ? "Remove Bookmark" : "Bookmark",
                    systemImage: store.expense.isBookmarked ? "bookmark.fill" : "bookmark"
                ) {
                    store.send(.bookmarkButtonTapped)
                }
                .labelStyle(.iconOnly)
                .tint(store.expense.isBookmarked ? .bookmark : .secondary)
            }
            ToolbarSpacer(.fixed, placement: .topBarTrailing)
            ToolbarItem(placement: .topBarTrailing) {
                Button("Edit") {
                    store.send(.editButtonTapped)
                }
            }
            ToolbarItem(placement: .bottomBar) {
                Button("Delete Expense", role: .destructive) {
                    store.send(.deleteButtonTapped)
                }
                .tint(.red)
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

#Preview("Bookmarked") {
    NavigationStack {
        ExpenseDetailView(
            store: Store(initialState: ExpenseDetail.State(expense: SharedReader(value: .blueMoon))) {
                ExpenseDetail()
            }
        )
    }
}

#Preview("Not Bookmarked") {
    NavigationStack {
        ExpenseDetailView(
            store: Store(initialState: ExpenseDetail.State(expense: SharedReader(value: .burningCandle))) {
                ExpenseDetail()
            }
        )
    }
}
