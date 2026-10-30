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
    let onSubmit: () -> Void

    var body: some View {
        OpenEntry(
            style: .text,
            title: title,
            display: Text(verbatim: store.text),
            isPlaceholder: store.text.isEmpty,
            isRefused: store.input.isInvalid,
            text: $store.text,
            focus: focus,
            field: field,
            placeholder: Text(title),
            onSubmit: onSubmit
        )
    }
}
