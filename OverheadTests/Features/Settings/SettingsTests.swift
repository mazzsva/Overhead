//
//  SettingsTests.swift
//  OverheadTests
//
//  Created by Lorenzo Mazzarotto on 31/08/26.
//

import AuthenticationServices
import ComposableArchitecture
import CustomDump
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

        // A sign out clears the local expenses
        @Test
        func theSignOutButtonAsksForConfirmation() async {
            let store = TestStore(initialState: Settings.State(user: .mock)) {
                Settings()
            }

            await store.send(.signOutButtonTapped) {
                $0.alert = .confirmSignOut
            }
        }

        // The app feature listens to Firebase, so the settings only start the sign out
        @Test
        func confirmingTheSignOutSignsTheUserOut() async {
            var state = Settings.State(user: .mock)
            state.alert = .confirmSignOut

            await confirmation("Signs the user out") { signsOut in
                let store = TestStore(initialState: state) {
                    Settings()
                } withDependencies: {
                    $0.authClient.signOut = { signsOut() }
                }

                await store.send(.alert(.presented(.confirmSignOut))) {
                    $0.alert = nil
                }
                await store.finish()
            }
        }

        // The settings stay on screen because the user is still signed in
        @Test
        func aFailedSignOutShowsAnAlert() async {
            var state = Settings.State(user: .mock)
            state.alert = .confirmSignOut

            let store = TestStore(initialState: state) {
                Settings()
            } withDependencies: {
                $0.authClient.signOut = { throw SignOutFailure() }
            }

            await store.send(.alert(.presented(.confirmSignOut))) {
                $0.alert = nil
            }
            await store.receive(\.signOutFailed) {
                $0.alert = .signOutFailed
            }
        }

        // A dismissed confirmation must not sign the user out
        @Test
        func dismissingTheAlertClearsIt() async {
            var state = Settings.State(user: .mock)
            state.alert = .confirmSignOut

            let store = TestStore(initialState: state) {
                Settings()
            }

            await store.send(.alert(.dismiss)) {
                $0.alert = nil
            }
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

        // The deletion removes the expenses from every device
        @Test
        func theDeleteAccountButtonAsksForConfirmation() async {
            let store = TestStore(initialState: Settings.State(user: .mock)) {
                Settings()
            }

            await store.send(.deleteAccountButtonTapped) {
                $0.alert = .confirmAccountDeletion
            }
        }

        // The account must exist until the expenses and the Apple token are gone
        @Test
        func confirmingTheAccountDeletionWalksThroughEveryStep() async {
            var state = Settings.State(user: .mock)
            state.alert = .confirmAccountDeletion

            let clock = TestClock()
            let deletions = LockIsolated<[String]>([])
            let store = TestStore(initialState: state) {
                Settings()
            } withDependencies: {
                $0.authClient.deleteAccount = {}
                $0.authClient.reauthenticate = { credential in
                    expectNoDifference(credential, .mock)
                }
                $0.authClient.revokeAppleToken = { authorizationCode in
                    expectNoDifference(authorizationCode, AppleCredential.mock.authorizationCode)
                }
                $0.budgetClient.delete = { uid in
                    expectNoDifference(uid, User.mock.uid)
                    deletions.withValue { $0.append("budget") }
                }
                $0.continuousClock = clock
                $0.expensesClient.deleteAll = { uid in
                    expectNoDifference(uid, User.mock.uid)
                    deletions.withValue { $0.append("expenses") }
                }
                $0.signInWithAppleClient.requestCredential = { .mock }
            }

            await store.send(.alert(.presented(.confirmAccountDeletion))) {
                $0.alert = nil
                $0.deletionStep = .reauthenticating
            }
            await store.receive(\.appleCredentialReceived) {
                $0.deletionStep = .deleting
            }
            await store.receive(\.budgetDeleted) {
                $0.deletionStep = .budgetDeleted
            }
            await store.receive(\.appleCredentialRevoked) {
                $0.deletionStep = .credentialRevoked
            }
            await store.finish()
            expectNoDifference(deletions.value, ["budget", "expenses"])
        }

        // The deletion must not stop halfway
        @Test
        func theButtonsAreIgnoredWhileTheAccountIsBeingDeleted() async {
            var state = Settings.State(user: .mock)
            state.deletionStep = .deleting

            let store = TestStore(initialState: state) {
                Settings()
            }

            await store.send(.deleteAccountButtonTapped)
            await store.send(.signOutButtonTapped)
        }

        // The user closed the Apple sheet, so the app returns to the settings
        @Test
        func aCanceledReauthorizationStopsTheDeletionSilently() async {
            var state = Settings.State(user: .mock)
            state.alert = .confirmAccountDeletion

            let store = TestStore(initialState: state) {
                Settings()
            } withDependencies: {
                $0.signInWithAppleClient.requestCredential = { throw ASAuthorizationError(.canceled) }
            }

            await store.send(.alert(.presented(.confirmAccountDeletion))) {
                $0.alert = nil
                $0.deletionStep = .reauthenticating
            }
            await store.receive(\.accountDeletionFailed) {
                $0.deletionStep = nil
            }
        }

        // Without the code the app cannot revoke the Apple token, so it deletes nothing
        @Test
        func aCredentialWithoutAnAuthorizationCodeFailsTheDeletion() async {
            var state = Settings.State(user: .mock)
            state.alert = .confirmAccountDeletion

            let store = TestStore(initialState: state) {
                Settings()
            } withDependencies: {
                $0.signInWithAppleClient.requestCredential = {
                    AppleCredential(
                        authorizationCode: nil,
                        idToken: "mock-id-token",
                        rawNonce: "mock-raw-nonce"
                    )
                }
            }

            await store.send(.alert(.presented(.confirmAccountDeletion))) {
                $0.alert = nil
                $0.deletionStep = .reauthenticating
            }
            await store.receive(\.accountDeletionFailed) {
                $0.alert = .accountDeletionFailed
                $0.deletionStep = nil
            }
        }

        // The deletion needs a recent sign in, and Firebase decides whether the credential counts
        @Test
        func aFailedReauthenticationShowsAnAlert() async {
            var state = Settings.State(user: .mock)
            state.alert = .confirmAccountDeletion

            let clock = TestClock()
            let store = TestStore(initialState: state) {
                Settings()
            } withDependencies: {
                $0.authClient.reauthenticate = { _ in throw DeletionFailure() }
                $0.continuousClock = clock
                $0.signInWithAppleClient.requestCredential = { .mock }
            }

            await store.send(.alert(.presented(.confirmAccountDeletion))) {
                $0.alert = nil
                $0.deletionStep = .reauthenticating
            }
            await store.receive(\.appleCredentialReceived) {
                $0.deletionStep = .deleting
            }
            await store.receive(\.accountDeletionFailed) {
                $0.alert = .accountDeletionFailed
                $0.deletionStep = nil
            }
            await store.finish()
        }

        // No expense is gone yet, so the alert must not report an unfinished deletion
        @Test
        func aFailureBeforeTheExpensesAreDeletedReportsAFailedDeletion() async {
            var state = Settings.State(user: .mock)
            state.alert = .confirmAccountDeletion

            let clock = TestClock()
            let store = TestStore(initialState: state) {
                Settings()
            } withDependencies: {
                $0.authClient.reauthenticate = { _ in }
                $0.budgetClient.delete = { _ in throw DeletionFailure() }
                $0.continuousClock = clock
                $0.signInWithAppleClient.requestCredential = { .mock }
            }

            await store.send(.alert(.presented(.confirmAccountDeletion))) {
                $0.alert = nil
                $0.deletionStep = .reauthenticating
            }
            await store.receive(\.appleCredentialReceived) {
                $0.deletionStep = .deleting
            }
            await store.receive(\.accountDeletionFailed) {
                $0.alert = .accountDeletionFailed
                $0.deletionStep = nil
            }
            await store.finish()
        }

        @Test
        func aFailedExpenseDeletionAfterTheBudgetReportsAnUnfinishedDeletion() async {
            var state = Settings.State(user: .mock)
            state.alert = .confirmAccountDeletion

            let clock = TestClock()
            let store = TestStore(initialState: state) {
                Settings()
            } withDependencies: {
                $0.authClient.reauthenticate = { _ in }
                $0.budgetClient.delete = { _ in }
                $0.continuousClock = clock
                $0.expensesClient.deleteAll = { _ in throw DeletionFailure() }
                $0.signInWithAppleClient.requestCredential = { .mock }
            }

            await store.send(.alert(.presented(.confirmAccountDeletion))) {
                $0.alert = nil
                $0.deletionStep = .reauthenticating
            }
            await store.receive(\.appleCredentialReceived) {
                $0.deletionStep = .deleting
            }
            await store.receive(\.budgetDeleted) {
                $0.deletionStep = .budgetDeleted
            }
            await store.receive(\.accountDeletionFailed) {
                $0.alert = .accountDeletionUnfinished
                $0.deletionStep = nil
            }
            await store.finish()
        }

        // The expenses are already gone, so the alert must not report a deletion that did not start
        @Test
        func aFailureAfterTheExpensesAreDeletedReportsAnUnfinishedDeletion() async {
            var state = Settings.State(user: .mock)
            state.alert = .confirmAccountDeletion

            let clock = TestClock()
            let store = TestStore(initialState: state) {
                Settings()
            } withDependencies: {
                $0.authClient.reauthenticate = { _ in }
                $0.authClient.revokeAppleToken = { _ in throw DeletionFailure() }
                $0.budgetClient.delete = { _ in }
                $0.continuousClock = clock
                $0.expensesClient.deleteAll = { _ in }
                $0.signInWithAppleClient.requestCredential = { .mock }
            }

            await store.send(.alert(.presented(.confirmAccountDeletion))) {
                $0.alert = nil
                $0.deletionStep = .reauthenticating
            }
            await store.receive(\.appleCredentialReceived) {
                $0.deletionStep = .deleting
            }
            await store.receive(\.budgetDeleted) {
                $0.deletionStep = .budgetDeleted
            }
            await store.receive(\.accountDeletionFailed) {
                $0.alert = .accountDeletionUnfinished
                $0.deletionStep = nil
            }
            await store.finish()
        }

        // Apple no longer trusts the app, so the session cannot continue
        @Test
        func aFailureAfterTheCredentialIsRevokedSignsTheUserOut() async {
            var state = Settings.State(user: .mock)
            state.alert = .confirmAccountDeletion

            let clock = TestClock()
            await confirmation("Signs the user out") { signsOut in
                let store = TestStore(initialState: state) {
                    Settings()
                } withDependencies: {
                    $0.authClient.deleteAccount = { throw DeletionFailure() }
                    $0.authClient.reauthenticate = { _ in }
                    $0.authClient.revokeAppleToken = { _ in }
                    $0.authClient.signOut = { signsOut() }
                    $0.budgetClient.delete = { _ in }
                    $0.continuousClock = clock
                    $0.expensesClient.deleteAll = { _ in }
                    $0.signInWithAppleClient.requestCredential = { .mock }
                }

                await store.send(.alert(.presented(.confirmAccountDeletion))) {
                    $0.alert = nil
                    $0.deletionStep = .reauthenticating
                }
                await store.receive(\.appleCredentialReceived) {
                    $0.deletionStep = .deleting
                }
                await store.receive(\.budgetDeleted) {
                    $0.deletionStep = .budgetDeleted
                }
                await store.receive(\.appleCredentialRevoked) {
                    $0.deletionStep = .credentialRevoked
                }
                await store.receive(\.accountDeletionFailed)
                await store.finish()
            }
        }

        // The user keeps a session that Apple no longer trusts, so the alert must say so
        @Test
        func aFailedSignOutAfterTheRevokeShowsAnAlert() async {
            var state = Settings.State(user: .mock)
            state.alert = .confirmAccountDeletion

            let clock = TestClock()
            let store = TestStore(initialState: state) {
                Settings()
            } withDependencies: {
                $0.authClient.deleteAccount = { throw DeletionFailure() }
                $0.authClient.reauthenticate = { _ in }
                $0.authClient.revokeAppleToken = { _ in }
                $0.authClient.signOut = { throw SignOutFailure() }
                $0.budgetClient.delete = { _ in }
                $0.continuousClock = clock
                $0.expensesClient.deleteAll = { _ in }
                $0.signInWithAppleClient.requestCredential = { .mock }
            }

            await store.send(.alert(.presented(.confirmAccountDeletion))) {
                $0.alert = nil
                $0.deletionStep = .reauthenticating
            }
            await store.receive(\.appleCredentialReceived) {
                $0.deletionStep = .deleting
            }
            await store.receive(\.budgetDeleted) {
                $0.deletionStep = .budgetDeleted
            }
            await store.receive(\.appleCredentialRevoked) {
                $0.deletionStep = .credentialRevoked
            }
            await store.receive(\.accountDeletionFailed)
            await store.receive(\.signOutFailed) {
                $0.alert = .signOutFailed
                $0.deletionStep = nil
            }
            await store.finish()
        }

        // A request that never returns leaves the user with a spinner
        @Test
        func aStalledDeletionTimesOutAfterOneMinute() async {
            var state = Settings.State(user: .mock)
            state.alert = .confirmAccountDeletion

            let clock = TestClock()
            let store = TestStore(initialState: state) {
                Settings()
            } withDependencies: {
                $0.authClient.reauthenticate = { _ in try await Task.never() }
                $0.continuousClock = clock
                $0.signInWithAppleClient.requestCredential = { .mock }
            }

            await store.send(.alert(.presented(.confirmAccountDeletion))) {
                $0.alert = nil
                $0.deletionStep = .reauthenticating
            }
            await store.receive(\.appleCredentialReceived) {
                $0.deletionStep = .deleting
            }

            await clock.advance(by: .seconds(60))
            await store.receive(\.accountDeletionFailed) {
                $0.alert = .accountDeletionFailed
                $0.deletionStep = nil
            }
            await store.finish()
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

        private struct DeletionFailure: Error {}

        private struct SignOutFailure: Error {}
    }
}
