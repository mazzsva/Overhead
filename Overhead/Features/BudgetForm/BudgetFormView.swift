//
//  BudgetFormView.swift
//  Overhead
//
//  Created by Lorenzo Mazzarotto on 04/10/26.
//

import ComposableArchitecture
import SwiftUI

struct BudgetFormView: View {
    @Bindable var store: StoreOf<BudgetForm>

    @FocusState private var focus: BudgetForm.Field?

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
                } header: {
                    Text("Income")
                } footer: {
                    Text("Your monthly pay after tax.")
                }
                Section {
                    TextField(
                        "Investments",
                        text: $store.investmentText,
                        prompt: Text(Decimal.zero, format: .dollars.locale(store.locale))
                    )
                    .keyboardType(.decimalPad)
                    .focused($focus, equals: .investment)
                    HStack {
                        ForEach(BudgetForm.investmentShares, id: \.self) { percent in
                            let share = Decimal(percent) / 100
                            Button {
                                store.send(.investmentShareButtonTapped(percent))
                            } label: {
                                Text(share, format: .percent)
                                    .frame(maxWidth: .infinity)
                            }
                            .accessibilityLabel(Text("Invest \(Text(share, format: .percent)) of Income"))
                        }
                    }
                    .buttonStyle(.bordered)
                    .buttonBorderShape(.capsule)
                    .disabled(store.income == nil)
                } header: {
                    Text("Investments")
                } footer: {
                    if store.investmentExceedsIncome {
                        Text("Your investments can't be more than your income.")
                    } else if store.isInvestmentInvalid {
                        Text("Enter a valid amount.")
                    } else if let share = store.investmentShare {
                        Text("\(Text(share, format: .percent.precision(.fractionLength(0)))) of your income.")
                    } else {
                        Text("Optional. The amount you invest each month.")
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
                    .disabled(store.budget == nil)
                }
                ToolbarItem(placement: .cancellationAction) {
                    Button("Dismiss", systemImage: "xmark") {
                        store.send(.dismissButtonTapped)
                    }
                    .foregroundStyle(.secondary)
                    .labelStyle(.iconOnly)
                }
            }
            .bind($store.focus, to: $focus)
        }
    }
}

#Preview("Add") {
    BudgetFormView(
        store: Store(initialState: BudgetForm.State(budget: nil, focus: .income)) {
            BudgetForm()
        }
    )
}

#Preview("Edit") {
    BudgetFormView(
        store: Store(initialState: BudgetForm.State(budget: .mock, focus: .investment)) {
            BudgetForm()
        }
    )
}
