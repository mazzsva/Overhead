//
//  AmountFieldTests.swift
//  OverheadTests
//
//  Created by Lorenzo Mazzarotto on 12/10/26.
//

import ComposableArchitecture
import CustomDump
import Foundation
import Testing

@testable import Overhead

extension BaseSuite {
    @Suite
    @MainActor
    struct AmountFieldTests {
        @Test
        func aNewFieldStartsEmptyWithTheMaximumLimit() {
            let state = AmountField.State()

            expectNoDifference(state.text, "")
            expectNoDifference(state.limit, .maximum)
            expectNoDifference(state.input, .empty)
            expectNoDifference(state.value, nil)
        }

        @Test
        func anAmountStartsFormattedInTheLocale() {
            let english = AmountField.State(1200)
            expectNoDifference(english.text, "1200")
            expectNoDifference(english.value, 1200)

            let italian = withDependencies {
                $0.locale = Locale(identifier: "it_IT")
            } operation: {
                AmountField.State(1200)
            }
            expectNoDifference(italian.text, "1200")
            expectNoDifference(italian.locale, Locale(identifier: "it_IT"))
        }

        @Test
        func theCurrencyComesFromTheLocale() {
            let state = withDependencies {
                $0.locale = Locale(identifier: "it_IT")
            } operation: {
                AmountField.State()
            }

            expectNoDifference(state.currency, .eur)
        }

        @Test
        func anAmountAboveTheLimitHasNoValue() {
            var state = AmountField.State(limit: 3000)

            state.text = "3000"
            expectNoDifference(state.value, 3000)

            state.text = "3001"
            expectNoDifference(state.input, .overLimit(3001))
            expectNoDifference(state.value, nil)

            state.limit = 4000
            expectNoDifference(state.value, 3001)
        }

        @Test
        func fillingWritesTheAmountInTheLocaleFormat() {
            var state = withDependencies {
                $0.locale = Locale(identifier: "it_IT")
            } operation: {
                AmountField.State()
            }

            state.fill(1500)

            expectNoDifference(state.text, "1500")
            expectNoDifference(state.value, 1500)
        }

        @Test
        func typingChangesTheText() async {
            let store = TestStore(initialState: AmountField.State()) {
                AmountField()
            }

            await store.send(.binding(.set(\.text, "1,200"))) {
                $0.text = "1,200"
            }
            expectNoDifference(store.state.value, 1200)
        }
    }
}
