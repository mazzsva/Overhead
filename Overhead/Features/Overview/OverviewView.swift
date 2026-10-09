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
    @Bindable var store: StoreOf<Overview>

    var body: some View {
        NavigationStack {
            List {
                Section {
                    VStack(alignment: .leading, spacing: 16) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Expenses")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                            if let monthlyTotal = store.monthlyTotal {
                                Text(monthlyTotal, format: .dollars)
                                    .font(.largeTitle)
                                    .fontWeight(.bold)
                                    .monospacedDigit()
                                Text("per month")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            } else {
                                Text("Your expenses couldn't be loaded.")
                                    .font(.title3)
                            }
                        }
                        .accessibilityElement(children: .combine)

                        if let breakdown = store.breakdown {
                            BudgetChart(breakdown: breakdown)
                        }
                    }
                    .padding(.vertical, 4)
                }

                Section {
                    switch store.budgetStatus {
                    case .failed:
                        Text("Your income couldn't be loaded.")
                            .foregroundStyle(.secondary)
                    case .loaded(let budget?):
                        Button {
                            store.send(.incomeRowTapped)
                        } label: {
                            LabeledContent("Income") {
                                Text(budget.income, format: .dollars)
                                    .foregroundStyle(.primary)
                                    .monospacedDigit()
                            }
                        }
                        .tint(.primary)
                        if let breakdown = store.breakdown {
                            Button {
                                store.send(.expensesRowTapped)
                            } label: {
                                BudgetRow(
                                    part: .expenses,
                                    subtitle: Text("^[\(store.activeExpenseCount) expense](inflect: true)"),
                                    amount: breakdown.expenses.amount,
                                    share: breakdown.expenses.share
                                )
                            }
                            .tint(.primary)
                        }
                        Button {
                            store.send(.investmentsRowTapped)
                        } label: {
                            BudgetRow(
                                part: .investments,
                                amount: budget.investment.map { -$0 },
                                share: store.breakdown?.investments?.share
                            )
                        }
                        .tint(.primary)
                        if let breakdown = store.breakdown {
                            BudgetRow(
                                part: .leftToSpend,
                                amount: breakdown.leftToSpend.amount,
                                share: breakdown.leftToSpend.share,
                                isOverBudget: breakdown.isOverBudget
                            )
                        }
                    case .loaded(nil):
                        IncomeSetUp {
                            store.send(.addIncomeButtonTapped)
                        }
                    case .offline:
                        Text("Connect to the internet to see your income.")
                            .foregroundStyle(.secondary)
                    case .loading:
                        ProgressView()
                            .frame(maxWidth: .infinity)
                    }
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
        .sheet(item: $store.scope(state: \.destination?.incomeForm, action: \.destination.incomeForm)) { formStore in
            IncomeFormView(store: formStore)
        }
        .sheet(
            item: $store.scope(state: \.destination?.investmentForm, action: \.destination.investmentForm)
        ) { formStore in
            InvestmentFormView(store: formStore)
        }
    }
}

extension Overview.BudgetPart {
    fileprivate var color: Color {
        switch self {
        case .expenses: .orange
        case .investments: .blue
        case .leftToSpend: .green
        }
    }

    fileprivate var title: LocalizedStringResource {
        switch self {
        case .expenses: "Expenses"
        case .investments: "Savings"
        case .leftToSpend: "Left to Spend"
        }
    }
}

private struct BudgetChart: View {
    let breakdown: Overview.Breakdown

    @ScaledMetric private var height = 12

    var body: some View {
        Chart(breakdown.chartSegments) { segment in
            BarMark(x: .value("Amount", segment.amount))
                .foregroundStyle(segment.part.color)
        }
        .chartXScale(domain: 0 ... breakdown.chartUpperBound)
        .chartXAxis(.hidden)
        .chartYAxis(.hidden)
        .chartPlotStyle { $0.clipShape(.capsule) }
        .frame(height: height)
        .accessibilityHidden(true)
    }
}

private struct IncomeSetUp: View {
    let onAdd: () -> Void

    @ScaledMetric private var height = 12

    private let sample = [
        Overview.Breakdown.Segment(amount: 46, part: .expenses),
        Overview.Breakdown.Segment(amount: 14, part: .investments),
        Overview.Breakdown.Segment(amount: 40, part: .leftToSpend),
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Chart(sample) { segment in
                BarMark(x: .value("Amount", segment.amount))
                    .foregroundStyle(segment.part.color.opacity(0.5))
            }
            .chartXScale(domain: 0 ... 100)
            .chartXAxis(.hidden)
            .chartYAxis(.hidden)
            .chartPlotStyle { $0.clipShape(.capsule) }
            .frame(height: height)
            .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 4) {
                Text("See What Is Left to Spend")
                    .font(.headline)
                Text("Add your monthly income to see how much remains after expenses and savings.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Button(action: onAdd) {
                Text("Add Income")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.glassProminent)
            .controlSize(.large)
            .buttonBorderShape(.capsule)
        }
        .padding(.vertical, 8)
    }
}

private struct BudgetRow: View {
    let part: Overview.BudgetPart
    var subtitle: Text?
    let amount: Decimal?
    let share: Decimal?
    var isOverBudget = false

    @ScaledMetric private var dotSize = 10

    var body: some View {
        LabeledContent {
            HStack(spacing: 12) {
                if let share {
                    Text(share, format: .percent.precision(.fractionLength(0)))
                        .foregroundStyle(.secondary)
                }
                if let amount {
                    Text(amount, format: .dollars)
                        .foregroundStyle(isOverBudget ? .red : .primary)
                } else {
                    Text("Add")
                        .foregroundStyle(Color.accentColor)
                }
            }
            .monospacedDigit()
        } label: {
            HStack(spacing: 12) {
                Circle()
                    .fill(part.color)
                    .frame(width: dotSize, height: dotSize)
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
        .accessibilityElement(children: .combine)
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
