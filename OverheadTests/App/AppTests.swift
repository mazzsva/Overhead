//
//  AppTests.swift
//  OverheadTests
//
//  Created by Lorenzo Mazzarotto on 01/09/26.
//

import AccountKit
import ComposableArchitecture
import CustomDump
import Testing

@testable import Overhead

extension BaseSuite {
    @Suite
    @MainActor
    struct AppTests {
        // Firestore keeps its cache on disk, so the app removes the expenses of the last user
        @Test
        func aSignedOutUserAtLaunchRoutesToSignInAndClearsTheLocalData() async {
            await confirmation("Clears the local data") { clearsLocalData in
                let store = TestStore(initialState: AccountSession<Home>.State()) {
                    AccountSession<Home>()
                } withDependencies: {
                    $0.expensesClient.clearLocalData = { clearsLocalData() }
                }

                await store.send(.authUserChanged(nil)) {
                    $0.scene = .signIn(SignIn.State())
                }
                await store.finish()
            }
        }

        // The message follows the step in progress, and a system sheet gets none
        @Test
        func theLoadingMessageDescribesWhatTheAppIsDoing() {
            var state = AccountSession<Home>.State()
            #expect(state.isLoading)
            expectNoDifference(state.loadingReason.map(AppView.loadingMessage), nil)

            var signIn = SignIn.State()
            signIn.step = .signingIn
            state.scene = .signIn(signIn)
            #expect(state.isLoading)
            expectNoDifference(state.loadingReason.map(AppView.loadingMessage), "Signing in…")

            var home = Home.State(user: .mock)
            home.accountDeletion = AccountDeletion.State(step: .reauthenticating, uid: AccountUser.mock.uid)
            state.scene = .home(home)
            #expect(state.isLoading)
            expectNoDifference(state.loadingReason.map(AppView.loadingMessage), nil)

            state.scene?.modify(\.home) { $0.accountDeletion?.step = .deleting }
            expectNoDifference(state.loadingReason.map(AppView.loadingMessage), "Deleting your account…")

            state.scene = .home(
                Home.State(user: .mock, sessionOrigin: .freshSignIn)
            )
            #expect(state.isLoading)
            expectNoDifference(state.loadingReason.map(AppView.loadingMessage), "Signing in…")

            signIn.step = .awaitingAuthorization
            state.scene = .signIn(signIn)
            #expect(state.isLoading)
            expectNoDifference(state.loadingReason.map(AppView.loadingMessage), nil)
        }

        // The Apple sheet covers the app, so the message waits for the deletion to start
        @Test
        func theLoadingMessageAppearsOnceTheAccountDeletionStarts() async {
            var home = Home.State(user: .mock)
            home.screen = .settings
            var state = AccountSession<Home>.State()
            state.scene = .home(home)

            let store = TestStore(initialState: state) {
                AccountSession<Home>()
            } withDependencies: {
                $0.authClient.appleUserID = { nil }
                $0.authClient.reauthenticate = { _ in try await Task.never() }
                $0.continuousClock = TestClock()
                $0.signInWithAppleClient.requestCredential = { .mock }
            }

            await store.send(\.scene.home.settings.account.deleteAccountButtonTapped) {
                $0.scene?.modify(\.home) { $0.settings.account.alert = .confirmAccountDeletion }
            }
            await store.send(.scene(.home(.settings(.account(.alert(.presented(.confirmAccountDeletion))))))) {
                $0.scene?.modify(\.home) { $0.settings.account.alert = nil }
            }
            await store.receive(\.scene.home.settings.account.delegate.didConfirmAccountDeletion) {
                $0.scene?
                    .modify(\.home) { home in
                        home.screen = nil
                        home.accountDeletion = AccountDeletion.State(uid: AccountUser.mock.uid)
                    }
            }
            await store.receive(\.scene.home.accountDeletion.presented.deletionConfirmed)
            expectNoDifference(store.state.loadingReason.map(AppView.loadingMessage), nil)

            await store.receive(\.scene.home.accountDeletion.presented.appleCredentialReceived) {
                $0.scene?.modify(\.home) { $0.accountDeletion?.step = .deleting }
            }
            expectNoDifference(store.state.loadingReason.map(AppView.loadingMessage), "Deleting your account…")
            await store.send(\.scene.home.accountDeletion.dismiss) {
                $0.scene?.modify(\.home) { $0.accountDeletion = nil }
            }
        }

        @Test
        func signingOutCancelsTheExpenseWritesInFlight() async {
            var home = Home.State(user: .mock)
            home.expenses.path.append(ExpenseDetail.State(expense: SharedReader(value: .rent)))
            let detailID = Array(home.expenses.path.ids)[0]
            var state = AccountSession<Home>.State()
            state.scene = .home(home)

            let pendingSave = LockIsolated<CheckedContinuation<Void, Never>?>(nil)
            let store = TestStore(initialState: state) {
                AccountSession<Home>()
            } withDependencies: {
                $0.continuousClock = ImmediateClock()
                $0.expensesClient.clearLocalData = {}
                $0.expensesClient.save = { _, _ in
                    await withCheckedContinuation { pendingSave.setValue($0) }
                    throw ExpensesFailure()
                }
            }

            await store.send(
                .scene(.home(.expenses(.path(.element(id: detailID, action: .delegate(.didUpdate(.rent)))))))
            )
            while pendingSave.value == nil {
                await Task.yield()
            }

            await store.send(.authUserChanged(nil)) {
                $0.isSignedOutSettling = true
            }
            await store.receive(\.signedOutCoverTimerElapsed) {
                $0.scene = .signIn(SignIn.State())
            }
            await store.receive(\.signedOutSettleTimerElapsed) {
                $0.isSignedOutSettling = false
            }

            pendingSave.value?.resume()
            await store.finish()
        }

        private struct ExpensesFailure: Error {}
    }
}
