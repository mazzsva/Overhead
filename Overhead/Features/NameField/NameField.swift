//
//  NameField.swift
//  Overhead
//
//  Created by Lorenzo Mazzarotto on 13/10/26.
//

import ComposableArchitecture
import Foundation

@Reducer
struct NameField {
    @ObservableState
    struct State: Equatable {
        var text: String

        init(_ name: ExpenseName? = nil) {
            text = name?.value ?? ""
        }

        var input: ExpenseNameInput {
            ExpenseNameInput(text: text)
        }

        var value: ExpenseName? {
            input.name
        }
    }

    enum Action: BindableAction {
        case binding(BindingAction<State>)
    }

    var body: some Reducer<State, Action> {
        BindingReducer()
    }
}
