//
//  ExpenseCardView.swift
//  Overhead
//
//  Created by Lorenzo Mazzarotto on 24/07/26.
//

import SwiftUI

struct ExpenseCardView: View {
    let expense: Expense

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(expense.name)
                    .font(.headline)
                    .foregroundStyle(expense.isActive ? .primary : .secondary)
                    .lineLimit(1)
                if !expense.isActive {
                    Text("Inactive")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                Text(expense.amount, format: .dollars)
                    .font(.headline)
                    .foregroundStyle(expense.isActive ? .primary : .secondary)
                    .monospacedDigit()
                Text(expense.billingCycle.title)
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            Color(.secondarySystemGroupedBackground),
            in: ConcentricRectangle(corners: .concentric(minimum: 16))
        )
        .contentShape(ConcentricRectangle(corners: .concentric(minimum: 16)))
        .accessibilityElement(children: .combine)
    }
}

#Preview {
    VStack(spacing: 16) {
        ForEach(Expense.mocks) { expense in
            ExpenseCardView(expense: expense)
        }
    }
    .padding()
    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    .groupedBackground()
}
