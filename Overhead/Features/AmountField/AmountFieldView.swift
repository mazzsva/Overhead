//
//  AmountFieldView.swift
//  Overhead
//
//  Created by Lorenzo Mazzarotto on 12/10/26.
//

import ComposableArchitecture
import SwiftUI

struct AmountFieldView<Field: Hashable & Sendable>: View {
    @Bindable var store: StoreOf<AmountField>
    let title: LocalizedStringResource
    let focus: FocusState<Field?>.Binding
    let field: Field

    var body: some View {
        let display = store.currency.displayText(amountText: store.text, locale: store.locale)
        OpenEntry(
            style: .amount,
            title: title,
            display: Text(verbatim: display),
            isPlaceholder: store.text.isEmpty,
            isRefused: store.input.isRefused,
            text: $store.text,
            focus: focus,
            field: field,
            accessibilityValue: Text(verbatim: display)
        )
    }
}
