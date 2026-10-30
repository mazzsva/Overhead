//
//  ExpenseFormView.swift
//  Overhead
//
//  Created by Lorenzo Mazzarotto on 20/07/26.
//

import ComposableArchitecture
import SwiftUI

struct ExpenseFormView: View {
    @Bindable var store: StoreOf<ExpenseForm>

    @FocusState private var focus: ExpenseForm.Field?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        EntrySheet(
            title: title,
            accent: .expense(isActive: store.isActive),
            cancellation: store.step == .name ? .cancel : .back,
            confirmation: store.step == .name ? .next : .save,
            canConfirm: store.step == .name ? store.name.value != nil : store.isSubmittable,
            locale: store.amount.locale,
            onCancellation: { store.send(store.step == .name ? .dismissButtonTapped : .backButtonTapped) },
            onConfirmation: { store.send(store.step == .name ? .nextButtonTapped : .saveButtonTapped) }
        ) {
            ZStack {
                NameFieldView(
                    store: store.scope(state: \.name, action: \.name),
                    title: "Title",
                    focus: $focus,
                    field: .name,
                    onSubmit: { store.send(.nameFieldSubmitted) }
                )
                .modifier(StepPage(isCurrent: store.step == .name, edge: .leading))
                AmountFieldView(
                    store: store.scope(state: \.amount, action: \.amount),
                    title: "Amount",
                    focus: $focus,
                    field: .amount
                )
                .modifier(StepPage(isCurrent: store.step == .amount, edge: .trailing))
            }
        } accessory: {
            if store.step == .amount {
                Group {
                    billingCycleChoices
                    if !store.isCreating {
                        activeToggle
                    }
                }
                .transition(
                    .asymmetric(
                        insertion: .opacity.combined(with: .offset(x: reduceMotion ? 0 : StepPage.distance)),
                        removal: .opacity.animation(.easeOut(duration: 0.12))
                    )
                )
            }
        }
        .animation(.step(reducingMotion: reduceMotion), value: store.step)
        .sensoryFeedback(.impact(weight: .light), trigger: store.step)
        .bind($store.focus, to: $focus)
    }

    private var activeToggle: some View {
        Toggle(isOn: $store.isActive.animation(.value(reducingMotion: reduceMotion))) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Active")
                Text(store.isActive ? "Counts toward your costs" : "Stays in your list, but not in your costs")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .contentTransition(.interpolate)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .cardBackground(.control)
    }

    private var billingCycleChoices: some View {
        ChoiceGroup {
            ForEach(BillingCycle.allCases, id: \.self) { billingCycle in
                ChoiceButton(
                    title: Text(billingCycle.title),
                    accent: .expense(isActive: store.isActive),
                    isSelected: store.billingCycle == billingCycle
                ) {
                    store.send(
                        .billingCycleButtonTapped(billingCycle), animation: .selection(reducingMotion: reduceMotion))
                } detail: {
                    Text(billingCycle.recurrence)
                }
            }
        }
        .sensoryFeedback(.selection, trigger: store.billingCycle)
    }

    private var title: Text {
        switch store.step {
        case .name:
            store.isCreating ? Text("New Expense") : Text("Edit Expense")
        case .amount:
            Text(verbatim: store.name.value?.value ?? "")
        }
    }
}

private struct StepPage: ViewModifier {
    static let distance: CGFloat = 72

    let isCurrent: Bool
    let edge: HorizontalEdge

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        let isMoved = !isCurrent && !reduceMotion
        content
            .offset(x: isMoved ? (edge == .leading ? -Self.distance : Self.distance) : 0)
            .blur(radius: isMoved ? 8 : 0)
            .opacity(isCurrent ? 1 : 0)
            .animation(animation, value: isCurrent)
            .allowsHitTesting(isCurrent)
            .accessibilityHidden(!isCurrent)
    }

    private var animation: Animation {
        if reduceMotion {
            return .fade
        }
        return isCurrent ? .step.delay(0.06) : .easeOut(duration: 0.16)
    }
}

#Preview("Create") {
    ExpenseFormView(
        store: Store(initialState: ExpenseForm.State()) {
            ExpenseForm()
        }
    )
}

#Preview("Edit") {
    ExpenseFormView(
        store: Store(initialState: ExpenseForm.State(expense: .gym)) {
            ExpenseForm()
        }
    )
}
