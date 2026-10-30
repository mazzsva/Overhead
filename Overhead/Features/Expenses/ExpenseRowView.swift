//
//  ExpenseRowView.swift
//  Overhead
//
//  Created by Lorenzo Mazzarotto on 24/07/26.
//

import SwiftUI

struct ExpenseRowView: View {
    let currency: Currency
    let expense: Expense
    let isHidden: Bool

    var body: some View {
        HStack(spacing: 12) {
            HStack(spacing: 8) {
                Marker(color: Accent.expense(isActive: expense.isActive).color)
                Text(expense.name.value)
                    .foregroundStyle(expense.isActive ? .primary : .secondary)
                    .lineLimit(1)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                AmountText(value: expense.amount.value, currency: currency, isHidden: isHidden)
                    .font(.system(.body, design: .rounded, weight: .semibold))
                    .foregroundStyle(expense.isActive ? .primary : .secondary)
                    .monospacedDigit()
                Text(expense.billingCycle.title)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityValue(expense.isActive ? Text(verbatim: "") : Text("Inactive"))
    }
}

#Preview {
    List(Expense.mocks) { expense in
        ExpenseRowView(currency: .usd, expense: expense, isHidden: false)
    }
}
