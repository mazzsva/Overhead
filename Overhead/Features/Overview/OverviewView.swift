//
//  OverviewView.swift
//  Overhead
//
//  Created by Lorenzo Mazzarotto on 01/10/26.
//

import ComposableArchitecture
import SwiftUI

struct OverviewView: View {
    @Bindable var store: StoreOf<Overview>
    let namespace: Namespace.ID

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        NavigationStack {
            Group {
                if let content = store.content {
                    ScrollView {
                        dashboard(content)
                    }
                    .contentMargins(.top, 8, for: .scrollContent)
                    .contentMargins(.bottom, 24, for: .scrollContent)
                    .scrollBounceBehavior(.basedOnSize)
                } else {
                    ContentUnavailableView(
                        "Unable to Load Expenses",
                        systemImage: "exclamationmark.triangle.fill",
                        description: Text("Overhead will try again automatically.")
                    )
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .groupedBackground()
            .navigationBarTitleDisplayMode(.inline)
            .toolbarRole(.editor)
            .toolbar {
                ToolbarItem(placement: .title) {
                    Text("Overview")
                        .font(.title)
                        .fontWeight(.bold)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Expenses", systemImage: "tray.full") {
                        store.send(.expensesButtonTapped)
                    }
                    .matchedTransitionSource(id: Home.Screen.expenses, in: namespace)
                }
                ToolbarSpacer(.fixed, placement: .topBarTrailing)
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Settings", systemImage: "gearshape") {
                        store.send(.settingsButtonTapped)
                    }
                    .matchedTransitionSource(id: Home.Screen.settings, in: namespace)
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

    private func dashboard(_ content: Overview.Content) -> some View {
        VStack(spacing: 12) {
            CostsHero(
                content: content,
                currency: store.currency,
                isHidingAmounts: store.hidesAmounts
            )

            TileGrid(
                content: content,
                currency: store.currency,
                expenseCount: store.activeExpenseCount ?? 0,
                isHidingAmounts: store.hidesAmounts,
                onExpenses: { store.send(.expensesButtonTapped) },
                onIncome: { store.send(.incomeTileTapped) },
                onSavings: { store.send(.savingsTileTapped) }
            )
        }
        .padding(.horizontal)
        .animation(reduceMotion ? .fade : .structure, value: content.summary == nil)
    }
}

extension Overview.Breakdown.ShareLabel {
    fileprivate var text: Text {
        switch self {
        case .lessThanOnePercent:
            Text("<\(Text(Decimal(1) / 100, format: .percent))")
        case .moreThanNinetyNinePercent:
            Text(">\(Text(Decimal(99) / 100, format: .percent))")
        case .moreThanOneHundredPercent:
            Text(">\(Text(Decimal(1), format: .percent))")
        case .percent(let share):
            Text(share, format: .percent.precision(.fractionLength(0)))
        }
    }
}

private struct CostsHero: View {
    let content: Overview.Content
    let currency: Currency
    let isHidingAmounts: Bool

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        HeroCard(title: "Monthly Costs", glow: glow, accessibilityValue: amountValue, hasCard: false) {
            AmountLabel(value: amount, currency: currency, isHidden: isHidingAmounts)
                .foregroundStyle(amount == 0 && !isHidingAmounts ? .tertiary : .primary)
                .redacted(reason: content.expensesOnly?.income == .loading ? .placeholder : [])
        } caption: {
            Text(caption)
        }
        .animation(.value(reducingMotion: reduceMotion), value: content.summary)
    }

    private var amount: Int {
        switch content {
        case .expensesOnly(let amount, _): amount
        case .summary(let breakdown): breakdown.committed.amount
        }
    }

    private var amountValue: Text {
        let amount = isHidingAmounts ? Text("Hidden") : Text(amount, format: .currency(currency))
        guard let breakdown = content.summary else { return amount }
        return Text("\(amount), \(breakdown.committedShareLabel.text) of income")
    }

    private var caption: LocalizedStringResource {
        content.summary?.savings == nil ? "Expenses, a month" : "Expenses and savings, a month"
    }

    private var glow: HeroGlow {
        guard let breakdown = content.summary else {
            return .breakdown(available: 0, expenses: amount > 0 ? 1 : 0, savings: 0)
        }
        return .breakdown(
            available: breakdown.isOverBudget ? 0 : breakdown.available.share.doubleValue,
            expenses: breakdown.expenses.share.doubleValue,
            savings: breakdown.savings?.share.doubleValue ?? 0
        )
    }
}

private struct TileGrid: View {
    private static let placeholderAmount = 1000

    let content: Overview.Content
    let currency: Currency
    let expenseCount: Int
    let isHidingAmounts: Bool
    let onExpenses: () -> Void
    let onIncome: () -> Void
    let onSavings: () -> Void

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        let row =
            dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(spacing: 12))
            : AnyLayout(HStackLayout(spacing: 12))
        VStack(spacing: 12) {
            row {
                incomeTile

                Button(action: onExpenses) {
                    expensesTile
                }
                .buttonStyle(.pressable(.tile))
            }
            .fixedSize(horizontal: false, vertical: true)

            if hasBudgetTiles {
                row {
                    Button(action: onSavings) {
                        savingsTile
                    }
                    .buttonStyle(.pressable(.tile))
                    .disabled(content.summary == nil)

                    availableTile
                }
                .fixedSize(horizontal: false, vertical: true)
                .transition(insertion)
            }
        }
    }

    private var availableTile: some View {
        let breakdown = content.summary
        let isOverBudget = breakdown?.isOverBudget ?? false
        return Tile(
            title: isOverBudget ? "Over Income" : "Available",
            accent: isOverBudget ? .overIncome : .available
        ) {
            AmountLabel(
                value: breakdown.map { abs($0.available.amount) } ?? Self.placeholderAmount,
                currency: currency,
                isHidden: isHidingAmounts
            )
            .foregroundStyle(isOverBudget ? Color.critical : .primary)
        } caption: {
            ShareBar(
                share: abs(breakdown?.available.share ?? 0),
                label: breakdown?.availableShareLabel ?? .percent(0),
                accent: isOverBudget ? .overIncome : .available
            )
        }
        .redacted(reason: breakdown == nil ? .placeholder : [])
        .animation(.value(reducingMotion: reduceMotion), value: breakdown)
    }

    private var expensesAmount: Int {
        switch content {
        case .expensesOnly(let amount, _): amount
        case .summary(let breakdown): breakdown.expenses.amount
        }
    }

    private var expensesTile: some View {
        Tile(title: "Expenses", accent: .expenses) {
            if expenseCount > 0 {
                AmountLabel(value: expensesAmount, currency: currency, isHidden: isHidingAmounts)
            } else {
                Text("Add Expense")
                    .foregroundStyle(.tint)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
            }
        } caption: {
            if let breakdown = content.summary, breakdown.hasExpenses {
                ShareBar(share: breakdown.expenses.share, label: breakdown.expensesShareLabel, accent: .expenses)
            } else if expenseCount > 0 {
                Text("^[\(expenseCount) expense](inflect: true)")
            } else {
                Text("No expenses yet")
            }
        }
        .animation(.value(reducingMotion: reduceMotion), value: content.summary)
    }

    private var hasBudgetTiles: Bool {
        content.summary != nil || content.expensesOnly?.income == .loading
    }

    private var incomeTile: some View {
        Button(action: onIncome) {
            Tile(title: "Income", accent: .income) {
                switch content {
                case .summary(let breakdown):
                    AmountLabel(value: breakdown.income, currency: currency, isHidden: isHidingAmounts)
                case .expensesOnly(_, .missing):
                    Text("Add Income")
                        .foregroundStyle(.tint)
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                case .expensesOnly(_, .loading):
                    AmountLabel(value: Self.placeholderAmount, currency: currency, isHidden: false)
                case .expensesOnly(_, .failed):
                    Image(systemName: "exclamationmark.circle")
                        .foregroundStyle(.secondary)
                        .accessibilityHidden(true)
                case .expensesOnly(_, .offline):
                    Image(systemName: "wifi.slash")
                        .foregroundStyle(.secondary)
                        .accessibilityHidden(true)
                }
            } caption: {
                switch content.expensesOnly?.income {
                case .failed:
                    Text("Your income couldn't be loaded.")
                case .missing:
                    Text("To see what is available")
                case .offline:
                    Text("Connect to the internet to see your income.")
                case .loading, nil:
                    Text("After tax")
                }
            }
            .redacted(reason: content.expensesOnly?.income == .loading ? .placeholder : [])
        }
        .buttonStyle(.pressable(.tile))
        .disabled(!canEditIncome)
    }

    private var canEditIncome: Bool {
        content.summary != nil || content.expensesOnly?.income == .missing
    }

    private var insertion: AnyTransition {
        reduceMotion
            ? .opacity
            : .asymmetric(
                insertion: .opacity.combined(with: .scale(scale: 0.96, anchor: .top)),
                removal: .opacity
            )
    }

    private var savingsTile: some View {
        Tile(title: "Savings", accent: .savings) {
            ZStack(alignment: .leading) {
                if content.summary == nil {
                    AmountLabel(value: Self.placeholderAmount, currency: currency, isHidden: false)
                } else if let savings = content.summary?.savings {
                    AmountLabel(value: savings.amount, currency: currency, isHidden: isHidingAmounts)
                        .transition(.replace(reducingMotion: reduceMotion))
                } else {
                    Text("Add Savings")
                        .foregroundStyle(.tint)
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                        .transition(.replace(reducingMotion: reduceMotion))
                }
            }
        } caption: {
            if let savings = content.summary?.savings, let label = content.summary?.savingsShareLabel {
                ShareBar(share: savings.share, label: label, accent: .savings)
            } else {
                Text("Optional")
            }
        }
        .redacted(reason: content.summary == nil ? .placeholder : [])
        .animation(.value(reducingMotion: reduceMotion), value: content.summary?.savings)
    }
}

private struct ShareBar: View {
    let share: Decimal
    let label: Overview.Breakdown.ShareLabel
    let accent: Accent

    @ScaledMetric(relativeTo: .footnote) private var height = 6

    var body: some View {
        HStack(spacing: 8) {
            Capsule()
                .fill(Color(.tertiarySystemFill))
                .overlay(alignment: .leading) {
                    GeometryReader { proxy in
                        Capsule()
                            .fill(LinearGradient(gradient: accent.gradient, startPoint: .leading, endPoint: .trailing))
                            .frame(width: filledWidth(of: proxy.size.width))
                    }
                }
                .clipShape(.capsule)
                .frame(height: height)
                .accessibilityHidden(true)

            label.text
                .monospacedDigit()
                .contentTransition(.numericText())
                .accessibilityLabel(Text("\(label.text) of income"))
        }
        .padding(.top, 4)
    }

    private func filledWidth(of width: CGFloat) -> CGFloat {
        let fraction = min(max(share.doubleValue, 0), 1)
        return fraction > 0 ? max(width * fraction, height) : 0
    }
}

#Preview {
    @Previewable @Namespace var namespace
    OverviewView(
        store: Store(
            initialState: Overview.State(
                budgetStatus: .loaded(.mock),
                expenses: SharedReader(value: IdentifiedArray(uniqueElements: Expense.mocks)),
                user: .mock
            )
        ) {
            Overview()
        },
        namespace: namespace
    )
}

#Preview("Without Income") {
    @Previewable @Namespace var namespace
    OverviewView(
        store: Store(
            initialState: Overview.State(
                budgetStatus: .loaded(nil),
                expenses: SharedReader(value: IdentifiedArray(uniqueElements: Expense.mocks)),
                user: .mock
            )
        ) {
            Overview()
        },
        namespace: namespace
    )
}
