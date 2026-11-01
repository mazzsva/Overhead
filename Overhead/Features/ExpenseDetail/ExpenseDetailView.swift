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

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        let expense = store.expense
        ScrollView {
            VStack(spacing: 12) {
                hero(expense)
                activeToggle
                DestructiveButton(title: "Delete Expense") {
                    store.send(.deleteButtonTapped)
                }
                .padding(.top, 12)
            }
            .padding(.horizontal)
            .animation(.value(reducingMotion: reduceMotion), value: expense)
        }
        .contentMargins(.top, 8, for: .scrollContent)
        .contentMargins(.bottom, 24, for: .scrollContent)
        .groupedBackground()
        .navigationTitle(expense.name.value)
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

    private func hero(_ expense: Expense) -> some View {
        let counterpart = expense.billingCycle.counterpart
        let amount = Text(expense.amount.value, format: .currency(store.currency))
        return HeroCard(
            title: expense.billingCycle.costTitle,
            glow: .accent(.expense(isActive: expense.isActive)),
            accessibilityValue: amount
        ) {
            AmountLabel(value: expense.amount.value, currency: store.currency)
                .foregroundStyle(expense.isActive ? .primary : .secondary)
        } caption: {
            counterpart.rate(
                Text(expense.billingCycle.amount(expense.amount, in: counterpart), format: .currency(store.currency))
            )
        }
    }

    private var activeToggle: some View {
        VStack(alignment: .leading, spacing: 8) {
            Toggle("Active", isOn: $store.expense.isActive.sending(\.activeToggleChanged))
                .tint(Accent.expenses.fill)
                .padding(.horizontal, 16)
                .frame(minHeight: 52)
                .cardBackground(.control)
            Text("Inactive expenses don't count toward your costs.")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 16)
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
