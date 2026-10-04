//
//  InvestmentFormView.swift
//  Overhead
//
//  Created by Lorenzo Mazzarotto on 04/10/26.
//

import ComposableArchitecture
import SwiftUI

struct InvestmentFormView: View {
    @Bindable var store: StoreOf<InvestmentForm>

    @FocusState private var focus: InvestmentForm.Field?

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField(
                        "Investments",
                        text: $store.investmentText,
                        prompt: Text(Decimal.zero, format: .dollars.locale(store.locale))
                    )
                    .keyboardType(.decimalPad)
                    .focused($focus, equals: .investment)
                    HStack {
                        ForEach(InvestmentForm.shares, id: \.self) { percent in
                            let share = Decimal(percent) / 100
                            Button {
                                store.send(.shareButtonTapped(percent))
                            } label: {
                                Text(share, format: .percent)
                                    .frame(maxWidth: .infinity)
                            }
                            .accessibilityLabel(Text("Invest \(Text(share, format: .percent)) of income"))
                        }
                    }
                    .buttonStyle(.bordered)
                    .buttonBorderShape(.capsule)
                } footer: {
                    if store.exceedsIncome {
                        Text("Your investments can't be more than your income.")
                    } else if store.isInvestmentInvalid {
                        Text("Enter a valid amount.")
                    } else if let share = store.share {
                        Text(
                            "\(Text(share, format: .percent.precision(.fractionLength(0)))) of your \(Text(store.income, format: .dollars.locale(store.locale))) income."
                        )
                    } else {
                        Text("The amount you invest each month.")
                    }
                }
                if store.isEditing {
                    Section {
                        Button("Remove Investments", role: .destructive) {
                            store.send(.removeButtonTapped)
                        }
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .groupedBackground()
            .navigationTitle("Investments")
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
                    Button("Cancel", systemImage: "xmark") {
                        store.send(.dismissButtonTapped)
                    }
                    .confirmationDialog(
                        $store.scope(state: \.destination?.confirmationDialog, action: \.destination.confirmationDialog)
                    )
                    .foregroundStyle(.secondary)
                    .labelStyle(.iconOnly)
                }
            }
            .interactiveDismissDisabled(store.hasChanges)
            .bind($store.focus, to: $focus)
            .alert($store.scope(state: \.destination?.alert, action: \.destination.alert))
        }
    }
}

#Preview("Add") {
    InvestmentFormView(
        store: Store(initialState: InvestmentForm.State(income: 3000, investment: nil)) {
            InvestmentForm()
        }
    )
}

#Preview("Edit") {
    InvestmentFormView(
        store: Store(initialState: InvestmentForm.State(income: 3000, investment: 450)) {
            InvestmentForm()
        }
    )
}
