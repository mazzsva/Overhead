//
//  SettingsTests.swift
//  OverheadTests
//
//  Created by Lorenzo Mazzarotto on 31/08/26.
//

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
        func theTaskLoadsTheBiometryType() async {
            let store = TestStore(initialState: Settings.State(user: .mock)) {
                Settings()
            } withDependencies: {
                $0.biometricsClient.biometryType = { .faceID }
                $0.currencyClient.currency = { _ in .never }
            }

            await store.send(.task) {
                $0.biometryType = .faceID
            }
            await store.skipInFlightEffects()
        }

        @Test
        func turningTheLockOnAsksForAuthenticationFirst() async {
            @Shared(.locksApp) var locksApp = false
            var state = Settings.State(user: .mock)
            state.biometryType = .faceID
            let store = TestStore(initialState: state) {
                Settings()
            } withDependencies: {
                $0.biometricsClient.authenticate = { _ in true }
            }

            await store.send(.lockToggleChanged(true)) {
                $0.$isAuthenticatingWithBiometrics.withLock { $0 = true }
            }
            await store.receive(\.lockAuthenticationResponse) {
                $0.$isAuthenticatingWithBiometrics.withLock { $0 = false }
                $0.$locksApp.withLock { $0 = true }
            }
        }

        @Test
        func aFailedAuthenticationLeavesTheLockOff() async {
            @Shared(.locksApp) var locksApp = false
            var state = Settings.State(user: .mock)
            state.biometryType = .touchID
            let store = TestStore(initialState: state) {
                Settings()
            } withDependencies: {
                $0.biometricsClient.authenticate = { _ in false }
            }

            await store.send(.lockToggleChanged(true)) {
                $0.$isAuthenticatingWithBiometrics.withLock { $0 = true }
            }
            await store.receive(\.lockAuthenticationResponse) {
                $0.$isAuthenticatingWithBiometrics.withLock { $0 = false }
            }
        }

        @Test
        func turningTheLockOffAlsoAsksForAuthentication() async {
            @Shared(.locksApp) var locksApp = true
            var state = Settings.State(user: .mock)
            state.biometryType = .faceID
            let store = TestStore(initialState: state) {
                Settings()
            } withDependencies: {
                $0.biometricsClient.authenticate = { _ in true }
            }

            await store.send(.lockToggleChanged(false)) {
                $0.$isAuthenticatingWithBiometrics.withLock { $0 = true }
            }
            await store.receive(\.lockAuthenticationResponse) {
                $0.$isAuthenticatingWithBiometrics.withLock { $0 = false }
                $0.$locksApp.withLock { $0 = false }
            }
        }

        // A sign out clears the local data
        @Test
        func theSignOutButtonAsksForConfirmation() async {
            let store = TestStore(initialState: Settings.State(user: .mock)) {
                Settings()
            }

            await store.send(.signOutButtonTapped) {
                $0.destination = .alert(.confirmSignOut)
            }
        }

        // The app feature listens to Firebase, so the settings only start the sign out
        @Test
        func confirmingTheSignOutSignsTheUserOut() async {
            await confirmation("Signs the user out") { signsOut in
                let store = TestStore(initialState: Settings.State(destination: .alert(.confirmSignOut), user: .mock)) {
                    Settings()
                } withDependencies: {
                    $0.authClient.signOut = { signsOut() }
                }

                await store.send(.destination(.presented(.alert(.confirmSignOut)))) {
                    $0.destination = nil
                }
                await store.finish()
            }
        }

        // The settings stay on screen because the user is still signed in
        @Test
        func aFailedSignOutShowsAnAlert() async {
            let store = TestStore(initialState: Settings.State(destination: .alert(.confirmSignOut), user: .mock)) {
                Settings()
            } withDependencies: {
                $0.authClient.signOut = { throw SignOutFailure() }
            }

            await store.send(.destination(.presented(.alert(.confirmSignOut)))) {
                $0.destination = nil
            }
            await store.receive(\.signOutFailed) {
                $0.destination = .alert(.signOutFailed)
            }
        }

        // A dismissed confirmation must not sign the user out
        @Test
        func dismissingTheAlertClearsIt() async {
            let store = TestStore(initialState: Settings.State(destination: .alert(.confirmSignOut), user: .mock)) {
                Settings()
            }

            await store.send(.destination(.dismiss)) {
                $0.destination = nil
            }
        }

        // The deletion removes the user data from every device
        @Test
        func theDeleteAccountButtonAsksForConfirmation() async {
            let store = TestStore(initialState: Settings.State(user: .mock)) {
                Settings()
            }

            await store.send(.deleteAccountButtonTapped) {
                $0.destination = .alert(.confirmAccountDeletion)
            }
        }

        @Test
        func confirmingTheAccountDeletionAsksHomeToDeleteTheAccount() async {
            let store = TestStore(
                initialState: Settings.State(destination: .alert(.confirmAccountDeletion), user: .mock)
            ) {
                Settings()
            }

            await store.send(.destination(.presented(.alert(.confirmAccountDeletion)))) {
                $0.destination = nil
            }
            await store.receive(\.delegate.didConfirmAccountDeletion)
        }

        // Every failure needs its own message, because the user decides what to do next from it
        @Test(
            arguments: [
                (
                    AccountDeletion.Failure.connectionFailed,
                    TextState("Your account couldn't be deleted. Check your connection and try again.")
                ),
                (.notDeleted, TextState("Your account couldn't be deleted.")),
                (.notFullyDeleted, TextState("Your account couldn't be fully deleted.")),
                (.notSignedOut, TextState("You couldn't be signed out.")),
            ] as [(AccountDeletion.Failure, TextState)]
        )
        func anAccountDeletionFailureHasItsOwnMessage(failure: AccountDeletion.Failure, message: TextState) {
            expectNoDifference(AlertState<Settings.Alert>.accountDeletionFailed(failure).message, message)
        }

        @Test
        func theCurrencyPickerSavesTheCurrency() async {
            let saved = LockIsolated<[Currency]>([])
            let store = TestStore(initialState: Settings.State(user: .mock)) {
                Settings()
            } withDependencies: {
                $0.currencyClient.save = { currency, uid in
                    expectNoDifference(uid, User.mock.uid)
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
                    expectNoDifference(uid, User.mock.uid)
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

        #if DEBUG
        // The button fills an empty account in the debug builds
        @Test
        func theDebugAddMockExpensesButtonSavesTheMockExpenses() async {
            let saved = LockIsolated<[Expense]>([])

            let store = TestStore(initialState: Settings.State(user: .mock)) {
                Settings()
            } withDependencies: {
                $0.expensesClient.save = { expense, uid in
                    expectNoDifference(uid, User.mock.uid)
                    saved.withValue { $0.append(expense) }
                }
            }

            await store.send(.debugAddMockExpensesButtonTapped)
            await store.finish()
            expectNoDifference(saved.value, Expense.mocks)
        }

        // The button clears the expenses and keeps the account
        @Test
        func theDebugDeleteAllExpensesButtonDeletesEveryExpense() async {
            await confirmation("Deletes all the expenses") { deletesAllExpenses in
                let store = TestStore(initialState: Settings.State(user: .mock)) {
                    Settings()
                } withDependencies: {
                    $0.expensesClient.deleteAll = { uid in
                        expectNoDifference(uid, User.mock.uid)
                        deletesAllExpenses()
                    }
                }

                await store.send(.debugDeleteAllExpensesButtonTapped)
                await store.finish()
            }
        }

        @Test
        func theDebugResetWelcomeToggleSetsTheFlagForTheNextLaunch() async {
            let store = TestStore(initialState: Settings.State(user: .mock)) {
                Settings()
            }

            await store.send(.debugResetWelcomeToggleChanged(true)) {
                $0.$showsWelcomeAtNextLaunch.withLock { $0 = true }
            }
            await store.send(.debugResetWelcomeToggleChanged(false)) {
                $0.$showsWelcomeAtNextLaunch.withLock { $0 = false }
            }
        }
        #endif

        private struct CurrencyFailure: Error {}

        private struct SignOutFailure: Error {}
    }
}
