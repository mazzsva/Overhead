//
//  NameFieldView.swift
//  Overhead
//
//  Created by Lorenzo Mazzarotto on 13/10/26.
//

import ComposableArchitecture
import SwiftUI

struct NameFieldView<Field: Hashable & Sendable>: View {
    @Bindable var store: StoreOf<NameField>
    let title: LocalizedStringResource
    let focus: FocusState<Field?>.Binding
    let field: Field
    var submitLabel = SubmitLabel.done
    let onSubmit: () -> Void

    private let fieldFont = Font.system(.title3, design: .rounded, weight: .semibold)

    @State private var refusals = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        let isInvalid = store.input.isInvalid
        let isFocused = focus.wrappedValue == field
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.footnote)
                    .foregroundStyle(isInvalid ? AnyShapeStyle(Color.critical) : AnyShapeStyle(.secondary))
                Text(verbatim: " ")
                    .font(fieldFont)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .hidden()
                    .overlay {
                        TextField(text: $store.text, prompt: Text("Groceries, Transportation, Utilities")) {
                            Text(title)
                        }
                        .font(fieldFont)
                        .textInputAutocapitalization(.words)
                        .autocorrectionDisabled()
                        .submitLabel(submitLabel)
                        .onSubmit(onSubmit)
                        .tint(Color.accentColor)
                        .focused(focus, equals: field)
                        .foregroundStyle(isInvalid ? AnyShapeStyle(Color.critical) : AnyShapeStyle(.primary))
                    }
            }
            if isFocused && !store.text.isEmpty {
                Button {
                    store.text = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title3)
                        .foregroundStyle(.tertiary)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(Text("Clear"))
                .transition(.opacity)
            }
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardBackground(.control)
        .overlay {
            CornerRadius.control.shape
                .stroke(Color.critical.opacity(isInvalid ? 0.7 : 0), lineWidth: 1.5)
        }
        .contentShape(.rect)
        .onTapGesture { focus.wrappedValue = field }
        .animation(.fade, value: isFocused)
        .animation(.fade, value: isInvalid)
        .keyframeAnimator(initialValue: 0.0, trigger: refusals) { content, offset in
            content.offset(x: offset)
        } keyframes: { _ in
            KeyframeTrack {
                LinearKeyframe(-10, duration: 0.06)
                LinearKeyframe(8, duration: 0.08)
                LinearKeyframe(-5, duration: 0.08)
                LinearKeyframe(3, duration: 0.07)
                LinearKeyframe(0, duration: 0.06)
            }
        }
        .sensoryFeedback(.error, trigger: isInvalid) { !$0 && $1 }
        .onChange(of: isInvalid) { _, isInvalid in
            guard isInvalid, !reduceMotion else { return }
            refusals += 1
        }
    }
}
