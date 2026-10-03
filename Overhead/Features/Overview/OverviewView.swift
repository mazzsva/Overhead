//
//  OverviewView.swift
//  Overhead
//
//  Created by Lorenzo Mazzarotto on 01/10/26.
//

import ComposableArchitecture
import SwiftUI

struct OverviewView: View {
    let store: StoreOf<Overview>

    var body: some View {
        NavigationStack {
            List {
                Section {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Monthly Total")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        Text(store.monthlyTotal, format: .dollars)
                            .font(.largeTitle)
                            .fontWeight(.bold)
                            .monospacedDigit()
                    }
                    .padding(.vertical, 4)
                    .accessibilityElement(children: .combine)
                } footer: {
                    Text("The total of your active expenses, with weekly and yearly amounts converted to a month.")
                }
            }
            .scrollContentBackground(.hidden)
            .groupedBackground()
            .contentMargins(.top, 8, for: .scrollContent)
            .navigationBarTitleDisplayMode(.inline)
            .toolbarRole(.editor)
            .toolbar {
                ToolbarItem(placement: .title) {
                    Text("Overview")
                        .font(.title)
                        .fontWeight(.bold)
                }
            }
        }
    }
}

#Preview {
    OverviewView(
        store: Store(
            initialState: Overview.State(expenses: SharedReader(value: IdentifiedArray(uniqueElements: Expense.mocks)))
        ) {
            Overview()
        }
    )
}
