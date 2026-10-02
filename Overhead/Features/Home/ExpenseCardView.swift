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
            VStack(alignment: .leading, spacing: 4) {
                Text(expense.term)
                    .font(.headline)
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                if !expense.definition.isEmpty {
                    Text(expense.definition)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)

            Divider()

            HStack {
                Text(expense.createdAt.formatted(date: .abbreviated, time: .omitted))
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundStyle(.secondary)
                Spacer()
                if expense.isBookmarked {
                    Image(systemName: "bookmark.fill")
                        .font(.caption)
                        .foregroundStyle(.bookmark)
                        .accessibilityLabel("Bookmarked")
                }
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
