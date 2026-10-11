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
            HeroCard(content: content) {
                store.send(.addIncomeButtonTapped)
            }

            if let breakdown = content.summary {
                TileGrid(
                    breakdown: breakdown,
                    onExpenses: { store.send(.expensesTileTapped) },
                    onIncome: { store.send(.incomeTileTapped) },
                    onSavings: { store.send(.savingsTileTapped) }
                )
            }
        }
        .padding(.horizontal)
    }
}

struct BarLayout: Equatable {
    struct Frame: Equatable {
        let width: Double
        let x: Double
    }

    static let minimumWidth = 6.0

    let frames: [Frame]
    let markX: Double?

    init(incomeMark: Double?, segments: [Overview.Breakdown.Segment], width: Double) {
        let gaps = segments.indices.map { Self.gap(before: $0, in: segments) }
        let usable = max(width - gaps.reduce(0, +), 0)
        var widths = segments.map { max(($0.end - $0.start) * usable, Self.minimumWidth) }
        let excess = widths.reduce(0, +) - usable
        if excess > 0, let widest = widths.indices.max(by: { widths[$0] < widths[$1] }) {
            widths[widest] = max(widths[widest] - excess, Self.minimumWidth)
        }
        var x = 0.0
        let frames = widths.indices.map { index in
            x += gaps[index]
            defer { x += widths[index] }
            return Frame(width: widths[index], x: x)
        }
        self.frames = frames
        markX = incomeMark.flatMap { mark in
            guard let index = segments.firstIndex(where: { $0.end >= mark }) else { return nil }
            let segment = segments[index]
            guard segment.end > segment.start else { return frames[index].x }
            return frames[index].x + (mark - segment.start) / (segment.end - segment.start) * frames[index].width
        }
    }

    static func gap(before index: Int, in segments: [Overview.Breakdown.Segment]) -> Double {
        guard index > 0 else { return 0 }
        return segments[index - 1].part.isCommitted == segments[index].part.isCommitted ? 3 : 6
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

extension Overview.BudgetPart {
    var isCommitted: Bool {
        self != .available
    }

    fileprivate var color: Color {
        switch self {
        case .available: .green
        case .expenses: .orange
        case .savings: .blue
        }
    }
}

private struct Amount: View {
    let value: Decimal

    var body: some View {
        Text(value, format: .dollars)
            .monospacedDigit()
            .lineLimit(1)
            .minimumScaleFactor(0.6)
    }
}

private struct HeroCard: View {
    let content: Overview.Content
    let onAddIncome: () -> Void

    @ScaledMetric(relativeTo: .largeTitle) private var amountSize = 44
    @ScaledMetric private var barHeight = 44
    @ScaledMetric(relativeTo: .caption2) private var barSpacing = 20
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Committed")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundStyle(.secondary)
                let amountLayout =
                    dynamicTypeSize >= .xxLarge
                    ? AnyLayout(VStackLayout(alignment: .leading, spacing: 0))
                    : AnyLayout(HStackLayout(alignment: .firstTextBaseline, spacing: 6))
                amountLayout {
                    Amount(value: amount)
                        .font(.system(size: amountSize, weight: .bold, design: .rounded))
                        .foregroundStyle(amount == 0 ? .tertiary : .primary)
                    Text("a month")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .fixedSize()
                }
            }
            .redacted(reason: isLoadingIncome ? .placeholder : [])
            .accessibilityElement(children: .combine)
            .accessibilityValue(shareOfIncome)

            barSlot
                .frame(height: min(barHeight, 64))
                .padding(.top, barSpacing)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(Color(.secondarySystemGroupedBackground), in: .rect(cornerRadius: 24, style: .continuous))
    }

    private var amount: Decimal {
        switch content {
        case .expensesOnly(let amount, _): amount
        case .summary(let breakdown): breakdown.committed.amount
        }
    }

    @ViewBuilder
    private var barSlot: some View {
        switch content {
        case .expensesOnly(_, .missing):
            Button(action: onAddIncome) {
                Label("Add Income", systemImage: "plus")
                    .font(.headline)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .buttonStyle(ProminentTrackButtonStyle())
        case .expensesOnly(_, .failed):
            Track(message: "Your income couldn't be loaded.")
        case .expensesOnly(_, .loading):
            Track(message: nil)
        case .expensesOnly(_, .offline):
            Track(message: "Connect to the internet to see your income.")
        case .summary(let breakdown):
            SegmentedBar(incomeMark: breakdown.incomeMark, segments: breakdown.segments)
        }
    }

    private var isLoadingIncome: Bool {
        content.expensesOnly?.income == .loading
    }

    private var shareOfIncome: Text {
        guard let breakdown = content.summary else { return Text(verbatim: "") }
        return Text("\(breakdown.committedShareLabel.text) of income")
    }
}

private struct ProminentTrackButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(.white)
            .background(.tint, in: .rect(cornerRadius: 12, style: .continuous))
            .contentShape(.rect(cornerRadius: 12, style: .continuous))
            .opacity(configuration.isPressed ? 0.7 : 1)
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .animation(.snappy(duration: 0.2), value: configuration.isPressed)
    }
}

private struct Track: View {
    let message: LocalizedStringResource?

    var body: some View {
        RoundedRectangle(cornerRadius: 12, style: .continuous)
            .fill(.quaternary)
            .overlay {
                if let message {
                    Text(message)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                        .minimumScaleFactor(0.8)
                        .padding(.horizontal, 12)
                }
            }
    }
}

private struct SegmentedBar: View {
    let incomeMark: Double?
    let segments: [Overview.Breakdown.Segment]

    @ScaledMetric private var markOverhang = 4
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        GeometryReader { proxy in
            let layout = BarLayout(incomeMark: incomeMark, segments: segments, width: proxy.size.width)
            ZStack(alignment: .leading) {
                ForEach(Array(segments.enumerated()), id: \.element.id) { index, segment in
                    UnevenRoundedRectangle(
                        topLeadingRadius: leadingRadius(at: index),
                        bottomLeadingRadius: leadingRadius(at: index),
                        bottomTrailingRadius: trailingRadius(at: index),
                        topTrailingRadius: trailingRadius(at: index),
                        style: .continuous
                    )
                    .fill(segment.part.color)
                    .frame(width: layout.frames[index].width)
                    .offset(x: layout.frames[index].x)
                }
            }
            .frame(width: proxy.size.width, height: proxy.size.height, alignment: .leading)
            .mask(alignment: .leading) {
                HStack(spacing: 0) {
                    Rectangle()
                        .frame(width: layout.markX ?? proxy.size.width)
                    Rectangle()
                        .opacity(colorScheme == .dark ? 0.5 : 0.35)
                }
            }
            .overlay(alignment: .topLeading) {
                if let markX = layout.markX {
                    IncomeMark(height: proxy.size.height + markOverhang * 2, width: proxy.size.width, x: markX)
                        .offset(y: -markOverhang)
                }
            }
        }
        .accessibilityHidden(true)
    }

    private func leadingRadius(at index: Int) -> Double {
        BarLayout.gap(before: index, in: segments) == 3 ? 4 : 12
    }

    private func trailingRadius(at index: Int) -> Double {
        index + 1 < segments.count && BarLayout.gap(before: index + 1, in: segments) == 3 ? 4 : 12
    }
}

private struct IncomeMark: View {
    let height: Double
    let width: Double
    let x: Double

    var body: some View {
        Capsule()
            .fill(.primary)
            .frame(width: 3, height: height)
            .padding(.horizontal, 2)
            .background(Color(.secondarySystemGroupedBackground), in: .capsule)
            .overlay(alignment: .top) {
                Text("Income")
                    .font(.caption2)
                    .fontWeight(.semibold)
                    .foregroundStyle(.secondary)
                    .fixedSize()
                    .alignmentGuide(.top) { $0[.bottom] + 4 }
                    .alignmentGuide(HorizontalAlignment.center) { x < width / 2 ? $0[.leading] - 4 : $0[.trailing] + 4 }
            }
            .offset(x: x - 3.5)
    }
}

private struct TileGrid: View {
    let breakdown: Overview.Breakdown
    let onExpenses: () -> Void
    let onIncome: () -> Void
    let onSavings: () -> Void

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        Group {
            if dynamicTypeSize.isAccessibilitySize {
                VStack(spacing: 12) {
                    incomeTile
                    expensesTile
                    savingsTile
                    availableTile
                }
            } else {
                Grid(horizontalSpacing: 12, verticalSpacing: 12) {
                    GridRow {
                        incomeTile
                        expensesTile
                    }
                    GridRow {
                        savingsTile
                        availableTile
                    }
                }
            }
        }
    }

    private var availableTile: some View {
        let isOverBudget = breakdown.isOverBudget
        let share = breakdown.availableShareLabel.text
        return Tile(
            title: isOverBudget ? "Over Budget" : "Available",
            color: isOverBudget ? .red : Overview.BudgetPart.available.color,
            tint: isOverBudget ? .red : .green
        ) {
            Amount(value: abs(breakdown.available.amount))
                .foregroundStyle(isOverBudget ? AnyShapeStyle(.red) : AnyShapeStyle(.primary))
        } caption: {
            if isOverBudget {
                Text("\(share) more than income")
            } else if breakdown.isFullyCommitted {
                Text("Fully committed")
            } else {
                Text("\(share) of income")
            }
        }
    }

    private var expensesTile: some View {
        Button(action: onExpenses) {
            Tile(title: "Expenses", color: Overview.BudgetPart.expenses.color) {
                Amount(value: breakdown.expenses.amount)
            } caption: {
                if breakdown.hasExpenses {
                    Text("\(breakdown.expensesShareLabel.text) of income")
                } else {
                    Text("No expenses yet")
                }
            }
        }
        .buttonStyle(TileButtonStyle())
    }

    private var incomeTile: some View {
        Button(action: onIncome) {
            Tile(title: "Income", color: .gray) {
                Amount(value: breakdown.income)
            } caption: {
                Text("a month, after tax")
            }
        }
        .buttonStyle(TileButtonStyle())
    }

    private var savingsTile: some View {
        Button(action: onSavings) {
            if let savings = breakdown.savings, let share = breakdown.savingsShareLabel {
                Tile(title: "Savings", color: Overview.BudgetPart.savings.color) {
                    Amount(value: savings.amount)
                } caption: {
                    Text("\(share.text) of income")
                }
            } else {
                Tile(title: "Savings", color: Overview.BudgetPart.savings.color) {
                    Text("Add Savings")
                        .foregroundStyle(.tint)
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                } caption: {
                    Text("Optional")
                }
            }
        }
        .buttonStyle(TileButtonStyle())
    }
}

private struct Tile<Value: View, Caption: View>: View {
    let title: LocalizedStringResource
    let color: Color
    var tint: Color?
    @ViewBuilder let value: Value
    @ViewBuilder let caption: Caption

    @ScaledMetric private var dotSize = 8

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 6) {
                Circle()
                    .fill(color)
                    .frame(width: dotSize, height: dotSize)
                Text(title)
                    .fontWeight(.semibold)
                    .foregroundStyle(.secondary)
            }
            .font(.subheadline)
            Spacer(minLength: 16)
            VStack(alignment: .leading, spacing: 2) {
                value
                    .font(.system(.title2, design: .rounded, weight: .semibold))
                caption
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .padding(16)
        .background {
            let shape = RoundedRectangle(cornerRadius: 22, style: .continuous)
            ZStack {
                shape.fill(Color(.secondarySystemGroupedBackground))
                if let tint {
                    shape.fill(tint.opacity(0.15))
                }
            }
        }
        .accessibilityElement(children: .combine)
    }
}

private struct TileButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(.primary)
            .contentShape(.rect(cornerRadius: 22, style: .continuous))
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.snappy(duration: 0.2), value: configuration.isPressed)
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
