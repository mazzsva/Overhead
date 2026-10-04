//
//  OverviewView.swift
//  Overhead
//
//  Created by Lorenzo Mazzarotto on 01/10/26.
//

import Charts
import ComposableArchitecture
import SwiftUI

struct OverviewView: View {
    let store: StoreOf<Overview>

    var body: some View {
        NavigationStack {
            List {
                Section {
                    VStack(alignment: .leading, spacing: 16) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Expenses")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                            Text(store.monthlyTotal, format: .dollars)
                                .font(.largeTitle)
                                .fontWeight(.bold)
                                .monospacedDigit()
                            Text("per month")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                        .accessibilityElement(children: .combine)

                        if let budget = store.budget {
                            BudgetChart(
                                budget: budget,
                                expenses: store.monthlyTotal,
                                leftToSpend: store.leftToSpend ?? 0
                            )
                        }
                    }
                    .padding(.vertical, 4)
                } footer: {
                    Text("The total of your active expenses, with weekly and yearly amounts converted to a month.")
                }

                switch store.budgetStatus {
                case .loaded(let budget?):
                    Section("Where Your Money Goes") {
                        LabeledContent("Income") {
                            Text(budget.income, format: .dollars)
                                .foregroundStyle(.primary)
                                .monospacedDigit()
                        }
                        Button {
                            store.send(.expensesRowTapped)
                        } label: {
                            BudgetRow(
                                part: .expenses,
                                subtitle: Text("^[\(store.activeExpenseCount) expense](inflect: true)"),
                                amount: -store.monthlyTotal,
                                share: store.expensesShare
                            )
                        }
                        .tint(.primary)
                        BudgetRow(
                            part: .investments,
                            amount: budget.investment.map { -$0 },
                            share: store.investmentShare
                        )
                        BudgetRow(
                            part: .leftToSpend,
                            amount: store.leftToSpend,
                            share: store.leftToSpendShare
                        )
                    }
                case .loaded(nil):
                    Section("Where Your Money Goes") {
                        Text("Add your income to see where your money goes.")
                            .foregroundStyle(.secondary)
                    }
                case .loading:
                    EmptyView()
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

private enum BudgetPart {
    case expenses
    case investments
    case leftToSpend

    var color: Color {
        switch self {
        case .expenses: .orange
        case .investments: .teal
        case .leftToSpend: .green
        }
    }

    var title: LocalizedStringResource {
        switch self {
        case .expenses: "Expenses"
        case .investments: "Investments"
        case .leftToSpend: "Left to Spend"
        }
    }
}

private struct BudgetChart: View {
    let budget: Budget
    let expenses: Decimal
    let leftToSpend: Decimal

    var body: some View {
        Chart(segments, id: \.part) { segment in
            BarMark(x: .value("Amount", segment.amount))
                .foregroundStyle(segment.part.color)
                .accessibilityLabel(Text(segment.part.title))
                .accessibilityValue(Text(segment.amount, format: .dollars))
        }
        .chartXScale(domain: 0 ... max(budget.income, expenses + (budget.investment ?? 0)))
        .chartXAxis(.hidden)
        .chartYAxis(.hidden)
        .chartPlotStyle { $0.clipShape(.capsule) }
        .frame(height: 12)
    }

    private var segments: [(part: BudgetPart, amount: Decimal)] {
        [
            (.expenses, expenses),
            (.investments, budget.investment ?? 0),
            (.leftToSpend, max(leftToSpend, 0)),
        ]
        .filter { $0.amount > 0 }
    }
}

private struct BudgetRow: View {
    let part: BudgetPart
    var subtitle: Text?
    let amount: Decimal?
    let share: Decimal?

    var body: some View {
        LabeledContent {
            HStack(spacing: 12) {
                if let share {
                    Text(share, format: .percent.precision(.fractionLength(0)))
                        .foregroundStyle(.secondary)
                }
                if let amount {
                    Text(amount, format: .dollars)
                        .foregroundStyle(part == .leftToSpend && amount < 0 ? .red : .primary)
                } else {
                    Text("None")
                        .foregroundStyle(.secondary)
                }
            }
            .monospacedDigit()
        } label: {
            HStack(spacing: 12) {
                Circle()
                    .fill(part.color)
                    .frame(width: 10, height: 10)
                VStack(alignment: .leading, spacing: 2) {
                    Text(part.title)
                    if let subtitle {
                        subtitle
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .fontWeight(part == .leftToSpend ? .semibold : nil)
    }
}

#Preview {
    OverviewView(
        store: Store(
            initialState: Overview.State(
                budgetStatus: .loaded(.mock),
                expenses: SharedReader(value: IdentifiedArray(uniqueElements: Expense.mocks)),
                user: .mock
            )
        ) {
            Overview()
        }
    )
}

#Preview("Without Income") {
    OverviewView(
        store: Store(
            initialState: Overview.State(
                budgetStatus: .loaded(nil),
                expenses: SharedReader(value: IdentifiedArray(uniqueElements: Expense.mocks)),
                user: .mock
            )
        ) {
            Overview()
        }
    )
}
