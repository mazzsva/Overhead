//
//  AmountField.swift
//  Overhead
//
//  Created by Lorenzo Mazzarotto on 12/10/26.
//

import ComposableArchitecture
import Foundation

@Reducer
struct AmountField {
    @ObservableState
    struct State: Equatable {
        @SharedReader(.currency) var currency
        let initial: Amount?
        var limit: Amount
        let locale: Locale
        var text: String

        init(_ amount: Amount? = nil, limit: Amount = .maximum) {
            @Dependency(\.locale) var locale
            initial = amount
            self.limit = limit
            self.locale = locale
            text = amount?.text(locale: locale) ?? ""
        }

        var input: AmountInput {
            AmountInput(text: text, locale: locale, limit: limit)
        }

        var value: Amount? {
            input.amount
        }

        mutating func fill(_ amount: Amount) {
            text = amount.text(locale: locale)
        }
    }

    enum Action: BindableAction {
        case binding(BindingAction<State>)
    }

    var body: some Reducer<State, Action> {
        BindingReducer()
    }
}
