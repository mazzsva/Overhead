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
                    Button(
                        store.hidesAmounts ? "Show Amounts" : "Hide Amounts",
                        systemImage: store.hidesAmounts ? "eye.slash" : "eye"
                    ) {
                        store.send(.amountsVisibilityButtonTapped, animation: reduceMotion ? nil : .value)
                    }
                    .contentTransition(.symbolEffect(.replace))
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
            Picker(
                "Period",
                selection: $store.period.sending(\.periodPickerChanged).animation(reduceMotion ? .fade : .value)
            ) {
                ForEach(Overview.Period.allCases, id: \.self) { period in
                    Text(period.title)
                }
            }
            .pickerStyle(.segmented)
            .sensoryFeedback(.selection, trigger: store.period)

            HeroCard(
                content: content,
                currency: store.currency,
                isHidingAmounts: store.hidesAmounts,
                period: store.period
            )

            TileGrid(
                content: content,
                currency: store.currency,
                expenseCount: store.activeExpenseCount ?? 0,
                isHidingAmounts: store.hidesAmounts,
                onExpenses: { store.send(.expensesTileTapped) },
                onIncome: { store.send(.incomeTileTapped) },
                onSavings: { store.send(.savingsTileTapped) }
            )
        }
        .padding(.horizontal)
        .animation(reduceMotion ? .fade : .structure, value: content.summary == nil)
    }
}

extension Animation {
    fileprivate static let fade = Animation.easeInOut(duration: 0.25)
    fileprivate static let glow = Animation.smooth(duration: 0.8)
    fileprivate static let press = Animation.snappy(duration: 0.2)
    fileprivate static let structure = Animation.spring(duration: 0.5, bounce: 0.1).delay(0.25)
    fileprivate static let value = Animation.snappy(duration: 0.4)
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

extension Color {
    fileprivate static let overIncome = Color(
        UIColor {
            $0.userInterfaceStyle == .dark
                ? UIColor(red: 1, green: 0.412, blue: 0.38, alpha: 1)
                : UIColor(red: 0.843, green: 0, blue: 0.082, alpha: 1)
        }
    )
}

extension Gradient {
    fileprivate static var available: Gradient {
        Gradient(colors: [.green.mix(with: .white, by: 0.25), .green])
    }

    fileprivate static var expenses: Gradient {
        Gradient(colors: [.orange.mix(with: .yellow, by: 0.3), .orange])
    }

    fileprivate static var overIncome: Gradient {
        Gradient(colors: [.red, .red])
    }

    fileprivate static var savings: Gradient {
        Gradient(colors: [.cyan, .blue])
    }
}

extension Overview.Period {
    fileprivate var costsTitle: LocalizedStringResource {
        switch self {
        case .day: "Daily Costs"
        case .week: "Weekly Costs"
        case .month: "Monthly Costs"
        case .year: "Yearly Costs"
        }
    }

    fileprivate var expensesAndSavingsCaption: LocalizedStringResource {
        switch self {
        case .day: "Expenses and savings, a day"
        case .week: "Expenses and savings, a week"
        case .month: "Expenses and savings, a month"
        case .year: "Expenses and savings, a year"
        }
    }

    fileprivate var expensesCaption: LocalizedStringResource {
        switch self {
        case .day: "Expenses, a day"
        case .week: "Expenses, a week"
        case .month: "Expenses, a month"
        case .year: "Expenses, a year"
        }
    }

    fileprivate var title: LocalizedStringResource {
        switch self {
        case .day: "Day"
        case .week: "Week"
        case .month: "Month"
        case .year: "Year"
        }
    }
}

private struct AmountLabel: View {
    let value: Int
    let currency: Currency
    let isHidden: Bool

    var body: some View {
        AmountText(value: value, currency: currency, isHidden: isHidden)
            .monospacedDigit()
            .contentTransition(.numericText(value: Double(value)))
            .lineLimit(1)
            .minimumScaleFactor(0.6)
    }
}

private struct Marker: View {
    let color: Color
    var isOutlined = false

    @ScaledMetric private var size = 10

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: size * 0.3, style: .continuous)
        ZStack {
            shape.fill(isOutlined ? .clear : color)
            shape.strokeBorder(isOutlined ? color : .clear, lineWidth: 1.5)
        }
        .frame(width: size, height: size)
    }
}

private struct HeroCard: View {
    let content: Overview.Content
    let currency: Currency
    let isHidingAmounts: Bool
    let period: Overview.Period

    @ScaledMetric(relativeTo: .largeTitle) private var amountSize = 48
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(spacing: 0) {
            Text(period.costsTitle)
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundStyle(.secondary)
                .contentTransition(.interpolate)
                .accessibilityHidden(true)

            AmountLabel(value: amount, currency: currency, isHidden: isHidingAmounts)
                .font(.system(size: amountSize, weight: .bold, design: .rounded))
                .kerning(-0.8)
                .foregroundStyle(amount == 0 && !isHidingAmounts ? .tertiary : .primary)
                .redacted(reason: content.expensesOnly?.income == .loading ? .placeholder : [])
                .padding(.top, 2)
                .accessibilityLabel(Text(period.costsTitle))
                .accessibilityValue(amountValue)

            Text(caption)
                .font(.footnote)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 20)
        .padding(.top, 20)
        .padding(.bottom, 22)
        .background {
            HeroBackground(glow: glow)
                .animation(reduceMotion ? .fade : .glow, value: glow)
        }
        .animation(reduceMotion ? .fade : .value, value: content.summary)
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
        content.summary?.savings == nil ? period.expensesCaption : period.expensesAndSavingsCaption
    }

    private var glow: HeroBackground.Glow {
        guard let breakdown = content.summary else {
            return HeroBackground.Glow(available: 0, expenses: amount > 0 ? 1 : 0, savings: 0)
        }
        return HeroBackground.Glow(
            available: breakdown.isOverBudget ? 0 : breakdown.available.share.doubleValue,
            expenses: breakdown.expenses.share.doubleValue,
            savings: breakdown.savings?.share.doubleValue ?? 0
        )
    }
}

private struct HeroBackground: View {
    struct Glow: Equatable {
        let available: Double
        let expenses: Double
        let savings: Double
    }

    let glow: Glow

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: 28, style: .continuous)
        let isDark = colorScheme == .dark
        shape
            .fill(
                LinearGradient(
                    colors: isDark
                        ? [Color(white: 0.17), Color(white: 0.12), Color(white: 0.1)]
                        : [
                            .white, Color(red: 0.97, green: 0.97, blue: 0.98),
                            Color(red: 0.93, green: 0.93, blue: 0.95),
                        ],
                    startPoint: UnitPoint(x: 0.35, y: 0),
                    endPoint: UnitPoint(x: 0.65, y: 1)
                )
            )
            .overlay(alignment: .top) {
                ZStack {
                    Ellipse()
                        .fill(Color.orange.opacity(opacity(for: glow.expenses)))
                        .frame(width: 240, height: 180)
                        .offset(x: -150)
                    Ellipse()
                        .fill(Color.green.opacity(opacity(for: glow.available)))
                        .frame(width: 200, height: 190)
                        .offset(y: -60)
                    Ellipse()
                        .fill(Color.blue.opacity(opacity(for: glow.savings)))
                        .frame(width: 260, height: 190)
                        .offset(x: 150)
                }
                .offset(y: -110)
                .blur(radius: 36)
                .allowsHitTesting(false)
                .accessibilityHidden(true)
            }
            .clipShape(shape)
            .overlay {
                shape.strokeBorder(.primary.opacity(isDark ? 0.1 : 0.06), lineWidth: 0.5)
            }
            .shadow(color: .black.opacity(isDark ? 0 : 0.06), radius: 15, y: 10)
    }

    private func opacity(for share: Double) -> Double {
        guard share > 0 else { return 0 }
        return (0.06 + 0.16 * min(share, 1)) * (colorScheme == .dark ? 1.15 : 1)
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
                Button(action: onExpenses) {
                    expensesTile
                }
                .buttonStyle(TileButtonStyle())

                if hasBudgetTiles {
                    Button(action: onSavings) {
                        savingsTile
                    }
                    .buttonStyle(TileButtonStyle())
                    .disabled(content.summary == nil)
                    .transition(insertion)
                } else {
                    incomeTile
                        .transition(.opacity)
                }
            }
            .fixedSize(horizontal: false, vertical: true)

            if hasBudgetTiles {
                row {
                    availableTile
                    incomeTile
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
            marker: Marker(color: isOverBudget ? .red : .green)
        ) {
            AmountLabel(
                value: breakdown.map { abs($0.available.amount) } ?? Self.placeholderAmount,
                currency: currency,
                isHidden: isHidingAmounts
            )
            .foregroundStyle(isOverBudget ? Color.overIncome : .primary)
        } caption: {
            ShareBar(
                share: abs(breakdown?.available.share ?? 0),
                label: breakdown?.availableShareLabel ?? .percent(0),
                gradient: isOverBudget ? .overIncome : .available
            )
        }
        .redacted(reason: breakdown == nil ? .placeholder : [])
        .animation(reduceMotion ? .fade : .value, value: breakdown)
    }

    private var expensesAmount: Int {
        switch content {
        case .expensesOnly(let amount, _): amount
        case .summary(let breakdown): breakdown.expenses.amount
        }
    }

    private var expensesTile: some View {
        Tile(title: "Expenses", marker: Marker(color: .orange)) {
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
                ShareBar(share: breakdown.expenses.share, label: breakdown.expensesShareLabel, gradient: .expenses)
            } else if expenseCount > 0 {
                Text("^[\(expenseCount) expense](inflect: true)")
            } else {
                Text("No expenses yet")
            }
        }
        .animation(reduceMotion ? .fade : .value, value: content.summary)
    }

    private var hasBudgetTiles: Bool {
        content.summary != nil || content.expensesOnly?.income == .loading
    }

    private var incomeTile: some View {
        Button(action: onIncome) {
            Tile(title: "Income", marker: Marker(color: .primary, isOutlined: true)) {
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
        .buttonStyle(TileButtonStyle())
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
        Tile(title: "Savings", marker: Marker(color: .blue)) {
            ZStack(alignment: .leading) {
                if content.summary == nil {
                    AmountLabel(value: Self.placeholderAmount, currency: currency, isHidden: false)
                } else if let savings = content.summary?.savings {
                    AmountLabel(value: savings.amount, currency: currency, isHidden: isHidingAmounts)
                        .transition(reduceMotion ? .opacity : AnyTransition(.blurReplace))
                } else {
                    Text("Add Savings")
                        .foregroundStyle(.tint)
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                        .transition(reduceMotion ? .opacity : AnyTransition(.blurReplace))
                }
            }
        } caption: {
            if let savings = content.summary?.savings, let label = content.summary?.savingsShareLabel {
                ShareBar(share: savings.share, label: label, gradient: .savings)
            } else {
                Text("Optional")
            }
        }
        .redacted(reason: content.summary == nil ? .placeholder : [])
        .animation(reduceMotion ? .fade : .value, value: content.summary?.savings)
    }
}

private struct ShareBar: View {
    let share: Decimal
    let label: Overview.Breakdown.ShareLabel
    let gradient: Gradient

    @ScaledMetric(relativeTo: .footnote) private var height = 6

    var body: some View {
        HStack(spacing: 8) {
            Capsule()
                .fill(Color(.tertiarySystemFill))
                .overlay(alignment: .leading) {
                    GeometryReader { proxy in
                        Capsule()
                            .fill(LinearGradient(gradient: gradient, startPoint: .leading, endPoint: .trailing))
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

private struct Tile<Value: View, Caption: View>: View {
    let title: LocalizedStringResource
    let marker: Marker
    @ViewBuilder let value: Value
    @ViewBuilder let caption: Caption

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                marker
                Text(title)
                    .fontWeight(.semibold)
                    .foregroundStyle(.secondary)
                    .contentTransition(.interpolate)
            }
            .font(.subheadline)
            .unredacted()
            VStack(alignment: .leading, spacing: 2) {
                value
                    .font(.system(.title2, design: .rounded, weight: .semibold))
                caption
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color(.secondarySystemGroupedBackground), in: .rect(cornerRadius: 22, style: .continuous))
        .accessibilityElement(children: .combine)
    }
}

private struct TileButtonStyle: ButtonStyle {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(.primary)
            .contentShape(.rect(cornerRadius: 22, style: .continuous))
            .brightness(configuration.isPressed ? (colorScheme == .dark ? 0.04 : -0.03) : 0)
            .scaleEffect(configuration.isPressed && !reduceMotion ? 0.97 : 1)
            .animation(.press, value: configuration.isPressed)
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
