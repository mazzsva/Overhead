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
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .firstTextBaseline) {
                Text(expense.name)
                    .lineLimit(1)
                Spacer()
                Text(expense.amount, format: .currency(code: expense.currencyCode))
                    .monospacedDigit()
            }
            .font(.headline)
            .foregroundStyle(.primary)
            .padding(.horizontal, 16)
            .padding(.vertical, 12)

            Divider()

            HStack {
                Text(expense.createdAt.formatted(date: .abbreviated, time: .omitted))
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundStyle(.secondary)
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
        }
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
