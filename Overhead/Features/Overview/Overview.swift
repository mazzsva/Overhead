//
//  Overview.swift
//  Overhead
//
//  Created by Lorenzo Mazzarotto on 04/10/26.
//

import ComposableArchitecture
import Foundation

@Reducer
struct Overview {
    @ObservableState
    struct State: Equatable {
        @SharedReader var expenses: IdentifiedArrayOf<Expense>?

        var monthlyTotal: Decimal {
            (expenses ?? []).filter(\.isActive).reduce(0) { $0 + $1.monthlyAmount }
        }
    }

    enum Action {}

    var body: some Reducer<State, Action> {
        EmptyReducer()
    }
}
