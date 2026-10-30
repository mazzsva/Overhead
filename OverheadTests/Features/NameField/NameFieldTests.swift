//
//  NameFieldTests.swift
//  OverheadTests
//
//  Created by Lorenzo Mazzarotto on 13/10/26.
//

import ComposableArchitecture
import CustomDump
import Foundation
import Testing

@testable import Overhead

extension BaseSuite {
    @Suite
    @MainActor
    struct NameFieldTests {
        @Test
        func aNewFieldStartsEmpty() {
            let state = NameField.State()

            expectNoDifference(state.text, "")
            expectNoDifference(state.input, .empty)
            expectNoDifference(state.value, nil)
        }

        @Test
        func aNameStartsFromItsValue() {
            let state = NameField.State("Gym")

            expectNoDifference(state.text, "Gym")
            expectNoDifference(state.value, "Gym")
        }

        @Test
        func theTextBindingChangesTheName() async {
            let store = TestStore(initialState: NameField.State()) {
                NameField()
            }

            await store.send(.binding(.set(\.text, "Netflix"))) {
                $0.text = "Netflix"
            }
            expectNoDifference(store.state.value, "Netflix")
        }
    }
}
