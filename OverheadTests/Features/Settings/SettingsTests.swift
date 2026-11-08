//
//  SettingsTests.swift
//  OverheadTests
//
//  Created by Lorenzo Mazzarotto on 31/08/26.
//

import AccountKit
import ComposableArchitecture
import CustomDump
import Foundation
import Testing

@testable import Overhead

extension BaseSuite {
    @Suite
    @MainActor
    struct SettingsTests {
        @Test
        func theInfoButtonPresentsTheAbout() async {
            let store = TestStore(initialState: Settings.State(user: .mock)) {
                Settings()
            }

            await store.send(.infoButtonTapped) {
                $0.isPresentingAbout = true
            }
            await store.send(.aboutPresentationChanged(false)) {
                $0.isPresentingAbout = false
            }
        }

        // A sign out clears the local data
        @Test
        func theSignOutButtonAsksForConfirmation() async {
            let store = TestStore(initialState: Settings.State(user: .mock)) {
                Settings()
            }

            await store.send(.account(.signOutButtonTapped)) {
                $0.account.alert = .confirmSignOut
            }
        }

        // The deletion removes the user data from every device
        @Test
        func theDeleteAccountButtonAsksForConfirmation() async {
            let store = TestStore(initialState: Settings.State(user: .mock)) {
                Settings()
            }

            await store.send(.account(.deleteAccountButtonTapped)) {
                $0.account.alert = .confirmAccountDeletion
            }
        }

        @Test
        func theCurrencyPickerSavesTheCurrency() async {
            let saved = LockIsolated<[Currency]>([])
            let store = TestStore(initialState: Settings.State(user: .mock)) {
                Settings()
            } withDependencies: {
                $0.currencyClient.save = { currency, uid in
                    expectNoDifference(uid, AccountUser.mock.uid)
                    saved.withValue { $0.append(currency) }
                }
            }

            await store.send(.currencyPickerChanged(.eur)) {
                $0.$currency.withLock { $0 = .eur }
            }
            await store.finish()
            expectNoDifference(saved.value, [.eur])
        }

        @Test
        func aFailedCurrencySaveIsReported() async {
            let store = TestStore(initialState: Settings.State(user: .mock)) {
                Settings()
            } withDependencies: {
                $0.currencyClient.save = { _, _ in throw CurrencyFailure() }
            }

            await store.send(.currencyPickerChanged(.brl)) {
                $0.$currency.withLock { $0 = .brl }
            }
            await store.receive(\.delegate.didFailToSaveCurrency)
        }

        @Test
        func theTaskObservesTheCurrency() async {
            let currency = AsyncThrowingStream<CurrencySnapshot, any Error>.makeStream()
            let store = TestStore(initialState: Settings.State(user: .mock)) {
                Settings()
            } withDependencies: {
                $0.currencyClient.currency = { uid in
                    expectNoDifference(uid, AccountUser.mock.uid)
                    return currency.stream
                }
            }

            let task = await store.send(.task)

            currency.continuation.yield(.known(.eur))
            await store.receive(\.currencyUpdated) {
                $0.$currency.withLock { $0 = .eur }
            }

            currency.continuation.yield(.unknown)
            await store.receive(\.currencyUpdated)

            currency.continuation.yield(.known(nil))
            await store.receive(\.currencyUpdated) {
                $0.$currency.withLock { $0 = .usd }
            }

            await task.cancel()
        }

        @Test
        func aFailedCurrencyStreamRetriesAfterFiveSeconds() async {
            let clock = TestClock()
            let attempts = LockIsolated(0)
            let store = TestStore(initialState: Settings.State(user: .mock)) {
                Settings()
            } withDependencies: {
                $0.continuousClock = clock
                $0.currencyClient.currency = { _ in
                    let attempt = attempts.withValue {
                        $0 += 1
                        return $0
                    }
                    return AsyncThrowingStream { continuation in
                        if attempt == 1 {
                            continuation.finish(throwing: CurrencyFailure())
                        } else {
                            continuation.yield(.known(.eur))
                            continuation.finish()
                        }
                    }
                }
            }

            await store.send(.task)
            await clock.advance(by: .seconds(4))
            expectNoDifference(attempts.value, 1)

            await clock.advance(by: .seconds(1))
            await store.receive(\.currencyUpdated) {
                $0.$currency.withLock { $0 = .eur }
            }
            await store.finish()
            expectNoDifference(attempts.value, 2)
        }

        private struct CurrencyFailure: Error {}
    }
}
