//
//  ExpenseForm.swift
//  Overhead
//
//  Created by Lorenzo Mazzarotto on 20/07/26.
//

import ComposableArchitecture
import Foundation

@Reducer
struct ExpenseForm {
    @ObservableState
    struct State: Equatable {
        var definition: String
        let expense: Expense?
        var term: String

        init(expense: Expense? = nil) {
            self.expense = expense
            definition = expense?.definition ?? ""
            term = expense?.term ?? ""
        }

        var isCreating: Bool {
            expense == nil
        }

        var isSubmittable: Bool {
            !term.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
    }

    enum Action: BindableAction {
        case binding(BindingAction<State>)
        case delegate(Delegate)
        case dismissButtonTapped
        case saveButtonTapped

        @CasePathable
        enum Delegate {
            case didSubmit(Expense)
        }
    }

    @Dependency(\.date.now) var now
    @Dependency(\.dismiss) var dismiss
    @Dependency(\.uuid) var uuid

    var body: some Reducer<State, Action> {
        BindingReducer()
        Reduce { state, action in
            switch action {
            case .binding:
                return .none

            case .delegate:
                return .none

            case .dismissButtonTapped:
                return .run { _ in await dismiss() }

            case .saveButtonTapped:
                guard state.isSubmittable else { return .none }
                let term = state.term.trimmingCharacters(in: .whitespacesAndNewlines)
                let definition = state.definition.trimmingCharacters(in: .whitespacesAndNewlines)
                let original = state.expense
                let expense = Expense(
                    createdAt: original?.createdAt ?? now,
                    definition: definition,
                    id: original?.id ?? uuid(),
                    term: term
                )
                return .send(.delegate(.didSubmit(expense)))
            }
        }
    }
}
