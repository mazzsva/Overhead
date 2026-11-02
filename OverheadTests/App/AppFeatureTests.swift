//
//  AppFeatureTests.swift
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
    struct AppFeatureTests {
        // Firebase and Apple report the two events that can start or end a session
        @Test
        func theTaskObservesTheAuthChangesAndTheCredentialRevocations() async {
            let authChanges = AsyncStream<AccountUser?>.makeStream()
            let revocations = AsyncStream<Void>.makeStream()

            await confirmation("Signs the user out") { signsOut in
                let store = TestStore(initialState: AppFeature.State()) {
                    AppFeature()
                } withDependencies: {
                    $0.authClient.appleUserID = { nil }
                    $0.authClient.authStateChanges = { authChanges.stream }
                    $0.authClient.signOut = { signsOut() }
                    $0.signInWithAppleClient.credentialRevocations = { revocations.stream }
                }

                await store.send(.task)

                authChanges.continuation.yield(.mock)
                await store.receive(\.authUserChanged) {
                    $0.scene = .home(Home.State(user: .mock))
                }

                revocations.continuation.yield()
                await store.receive(\.appleCredentialRevoked)

                authChanges.continuation.finish()
                revocations.continuation.finish()
                await store.finish()
            }
        }

        // Apple can revoke the credential while the app does not run
        @Test
        func aSignedInUserAtLaunchRoutesToHomeAndVerifiesTheCredential() async {
            await confirmation("Verifies the Apple credential") { verifiesCredential in
                let store = TestStore(initialState: AppFeature.State()) {
                    AppFeature()
                } withDependencies: {
                    $0.authClient.appleUserID = { "apple-user" }
                    $0.signInWithAppleClient.credentialState = { userID in
                        expectNoDifference(userID, "apple-user")
                        verifiesCredential()
                        return .authorized
                    }
                }

                await store.send(.authUserChanged(.mock)) {
                    $0.scene = .home(Home.State(user: .mock))
                }
                await store.finish()
            }
        }

        @Test
        func aSignedInUserAtLaunchKeepsTheSessionWhenTheCredentialIsNotFound() async {
            await confirmation("Verifies the Apple credential") { verifiesCredential in
                let store = TestStore(initialState: AppFeature.State()) {
                    AppFeature()
                } withDependencies: {
                    $0.authClient.appleUserID = { "apple-user" }
                    $0.signInWithAppleClient.credentialState = { _ in
                        verifiesCredential()
                        return .notFound
                    }
                }

                await store.send(.authUserChanged(.mock)) {
                    $0.scene = .home(Home.State(user: .mock))
                }
                await store.finish()
            }
        }

        // Firestore keeps its cache on disk, so the app removes the expenses of the last user
        @Test
        func aSignedOutUserAtLaunchRoutesToSignInAndClearsTheLocalData() async {
            await confirmation("Clears the local data") { clearsLocalData in
                let store = TestStore(initialState: AppFeature.State()) {
                    AppFeature()
                } withDependencies: {
                    $0.expensesClient.clearLocalData = { clearsLocalData() }
                }

                await store.send(.authUserChanged(nil)) {
                    $0.scene = .signIn(SignIn.State())
                }
                await store.finish()
            }
        }

        // The welcome must not cover the loading screen at launch
        @Test
        func theWelcomeIsPresentedOnlyOnceTheAppIsReady() {
            var state = AppFeature.State()
            #expect(!state.isPresentingWelcome)

            state.scene = .signIn(SignIn.State())
            #expect(state.isPresentingWelcome)

            state.$hasDismissedWelcome.withLock { $0 = true }
            #expect(!state.isPresentingWelcome)
        }

        // App storage keeps the flag, so the welcome does not return at the next launch
        @Test
        func theWelcomeContinueButtonDismissesItForGood() async {
            var state = AppFeature.State()
            state.scene = .signIn(SignIn.State())

            let store = TestStore(initialState: state) {
                AppFeature()
            }

            await store.send(.welcomeContinueButtonTapped) {
                $0.$hasDismissedWelcome.withLock { $0 = true }
            }
            #expect(!store.state.isPresentingWelcome)
        }

        @Test
        func theWelcomeDismissedBySwiftUIIsDismissedForGood() async {
            var state = AppFeature.State()
            state.scene = .signIn(SignIn.State())

            let store = TestStore(initialState: state) {
                AppFeature()
            }

            await store.send(.welcomePresentationChanged(true))
            await store.send(.welcomePresentationChanged(false)) {
                $0.$hasDismissedWelcome.withLock { $0 = true }
            }
            #expect(!store.state.isPresentingWelcome)
        }

        #if DEBUG
        @Test
        func theDebugFlagBringsTheWelcomeBackAtLaunch() async {
            @Shared(.hasDismissedWelcome) var hasDismissedWelcome = true
            @Shared(.showsWelcomeAtNextLaunch) var showsWelcomeAtNextLaunch = true

            let store = TestStore(initialState: AppFeature.State()) {
                AppFeature()
            } withDependencies: {
                $0.authClient.authStateChanges = { AsyncStream { $0.finish() } }
                $0.signInWithAppleClient.credentialRevocations = { AsyncStream { $0.finish() } }
            }

            await store.send(.task) {
                $0.$hasDismissedWelcome.withLock { $0 = false }
                $0.$showsWelcomeAtNextLaunch.withLock { $0 = false }
            }
            await store.finish()
        }
        #endif

        // Firebase reports no user while the sign in is in progress
        @Test
        func aSignedOutUserOnTheSignInIsIgnored() async {
            var state = AppFeature.State()
            state.scene = .signIn(SignIn.State())

            let store = TestStore(initialState: state) {
                AppFeature()
            }

            await store.send(.authUserChanged(nil))
        }

        // The sign in scene shows first at launch, so a restored session comes through it
        @Test
        func aRestoredSessionRoutesToHomeAndVerifiesTheCredential() async {
            var state = AppFeature.State()
            state.scene = .signIn(SignIn.State())

            await confirmation("Verifies the Apple credential") { verifiesCredential in
                let store = TestStore(initialState: state) {
                    AppFeature()
                } withDependencies: {
                    $0.authClient.appleUserID = { "apple-user" }
                    $0.signInWithAppleClient.credentialState = { _ in
                        verifiesCredential()
                        return .authorized
                    }
                }

                await store.send(.authUserChanged(.mock)) {
                    $0.scene = .home(Home.State(user: .mock, sessionOrigin: .restored))
                }
                await store.finish()
            }
        }

        // Apple authorized the user a moment ago, so the app does not check the credential again
        @Test
        func finishingTheSignInRoutesToHomeAsAFreshSignIn() async {
            var signIn = SignIn.State()
            signIn.step = .signingIn
            var state = AppFeature.State()
            state.scene = .signIn(signIn)

            let store = TestStore(initialState: state) {
                AppFeature()
            }

            await store.send(.authUserChanged(.mock)) {
                $0.scene = .home(
                    Home.State(user: .mock, sessionOrigin: .freshSignIn)
                )
            }
            await store.finish()
        }

        // Firebase sends the same user again after each token refresh
        @Test
        func theSameSignedInUserIsIgnored() async {
            var state = AppFeature.State()
            state.scene = .home(Home.State(user: .mock))

            let store = TestStore(initialState: state) {
                AppFeature()
            }

            await store.send(.authUserChanged(.mock))
        }

        // The user can revoke the Apple ID while the app is in the background
        @Test
        func becomingActiveSignsTheUserOutWhenTheCredentialIsRevoked() async {
            var state = AppFeature.State()
            state.scene = .home(Home.State(user: .mock))

            await confirmation("Signs the user out") { signsOut in
                let store = TestStore(initialState: state) {
                    AppFeature()
                } withDependencies: {
                    $0.authClient.appleUserID = { "apple-user" }
                    $0.authClient.signOut = { signsOut() }
                    $0.signInWithAppleClient.credentialState = { _ in .revoked }
                }

                await store.send(.appBecameActive)
                await store.receive(\.appleCredentialRevoked)
                await store.finish()
            }
        }

        @Test(arguments: [.notFound, .transferred, .unknown] as [AppleCredentialState])
        func becomingActiveKeepsTheSessionWhenTheCredentialIsNotRevoked(credentialState: AppleCredentialState) async {
            var state = AppFeature.State()
            state.scene = .home(Home.State(user: .mock))

            await confirmation("Verifies the Apple credential") { verifiesCredential in
                let store = TestStore(initialState: state) {
                    AppFeature()
                } withDependencies: {
                    $0.authClient.appleUserID = { "apple-user" }
                    $0.signInWithAppleClient.credentialState = { _ in
                        verifiesCredential()
                        return credentialState
                    }
                }

                await store.send(.appBecameActive)
                await store.finish()
            }
        }

        // The deletion revokes the credential itself, and a sign out would stop it
        @Test
        func theCredentialChecksAreIgnoredWhileDeletingTheAccount() async {
            var home = Home.State(user: .mock)
            home.accountDeletion = AccountDeletion.State(step: .credentialRevoked, uid: AccountUser.mock.uid)
            var state = AppFeature.State()
            state.scene = .home(home)

            let store = TestStore(initialState: state) {
                AppFeature()
            }

            await store.send(.appBecameActive)
            await store.send(.appleCredentialRevoked)
        }

        @Test(
            arguments: [nil, .connectionFailed, .notDeleted, .notFullyDeleted, .notSignedOut]
                as [AccountDeletion.Failure?]
        )
        func endingTheAccountDeletionVerifiesTheCredential(failure: AccountDeletion.Failure?) async {
            var home = Home.State(user: .mock)
            home.accountDeletion = AccountDeletion.State(uid: AccountUser.mock.uid)
            var state = AppFeature.State()
            state.scene = .home(home)

            await confirmation("Signs the user out") { signsOut in
                let store = TestStore(initialState: state) {
                    AppFeature()
                } withDependencies: {
                    $0.authClient.appleUserID = { "apple-user" }
                    $0.authClient.signOut = { signsOut() }
                    $0.signInWithAppleClient.credentialState = { _ in .revoked }
                }

                let delegate: AccountDeletion.Action.Delegate = failure.map { .didFail($0) } ?? .didCancel
                await store.send(.scene(.home(.accountDeletion(.presented(.delegate(delegate)))))) {
                    $0.scene?
                        .modify(\.home) { home in
                            home.accountDeletion = nil
                            home.screen = .settings
                            home.settings.account.alert = failure.map { .accountDeletionFailed($0) }
                        }
                }
                await store.receive(\.appleCredentialRevoked)
                await store.finish()
            }
        }

        // The message follows the step in progress, and a system sheet gets none
        @Test
        func theLoadingMessageDescribesWhatTheAppIsDoing() {
            var state = AppFeature.State()
            #expect(state.isLoading)
            expectNoDifference(state.loadingMessage, nil)

            var signIn = SignIn.State()
            signIn.step = .signingIn
            state.scene = .signIn(signIn)
            #expect(state.isLoading)
            expectNoDifference(state.loadingMessage, "Signing in…")

            var home = Home.State(user: .mock)
            home.accountDeletion = AccountDeletion.State(step: .reauthenticating, uid: AccountUser.mock.uid)
            state.scene = .home(home)
            #expect(state.isLoading)
            expectNoDifference(state.loadingMessage, nil)

            state.scene?.modify(\.home) { $0.accountDeletion?.step = .deleting }
            expectNoDifference(state.loadingMessage, "Deleting your account…")

            state.scene = .home(
                Home.State(user: .mock, sessionOrigin: .freshSignIn)
            )
            #expect(state.isLoading)
            expectNoDifference(state.loadingMessage, "Signing in…")

            signIn.step = .awaitingAuthorization
            state.scene = .signIn(signIn)
            #expect(state.isLoading)
            expectNoDifference(state.loadingMessage, nil)
        }

        // The Apple sheet covers the app, so the message waits for the deletion to start
        @Test
        func theLoadingMessageAppearsOnceTheAccountDeletionStarts() async {
            var home = Home.State(user: .mock)
            home.screen = .settings
            var state = AppFeature.State()
            state.scene = .home(home)

            let store = TestStore(initialState: state) {
                AppFeature()
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
            expectNoDifference(store.state.loadingMessage, nil)

            await store.receive(\.scene.home.accountDeletion.presented.appleCredentialReceived) {
                $0.scene?.modify(\.home) { $0.accountDeletion?.step = .deleting }
            }
            expectNoDifference(store.state.loadingMessage, "Deleting your account…")
            await store.send(\.scene.home.accountDeletion.dismiss) {
                $0.scene?.modify(\.home) { $0.accountDeletion = nil }
            }
        }

        // Auth must not change accounts without a sign out, so the app also reports an issue
        @Test
        func switchingAccountsRestartsTheSession() async {
            let other = AccountUser(email: "other@example.com", uid: "other-uid")
            var state = AppFeature.State()
            state.scene = .home(Home.State(user: .mock))

            let store = TestStore(initialState: state) {
                AppFeature()
            } withDependencies: {
                $0.authClient.appleUserID = { nil }
                $0.authClient.currentUser = { other }
                $0.expensesClient.clearLocalData = {}
            }

            await withKnownIssue {
                await store.send(.authUserChanged(other)) {
                    $0.scene = nil
                }
            } matching: {
                $0.comments.contains { $0.rawValue == "Auth changed accounts without signing out first." }
            }
            await store.receive(\.authUserChanged, other) {
                $0.scene = .home(Home.State(user: other))
            }
            await store.finish()
        }

        @Test
        func aSignOutDuringTheAccountSwitchEndsAtTheSignIn() async {
            let events = LockIsolated<[String]>([])
            var state = AppFeature.State()
            state.scene = .home(Home.State(user: .mock))

            let store = TestStore(initialState: state) {
                AppFeature()
            } withDependencies: {
                $0.authClient.currentUser = {
                    events.withValue { $0.append("currentUser") }
                    return nil
                }
                $0.expensesClient.clearLocalData = { events.withValue { $0.append("clearLocalData") } }
            }

            await withKnownIssue {
                await store.send(.authUserChanged(AccountUser(email: "other@example.com", uid: "other-uid"))) {
                    $0.scene = nil
                }
            } matching: {
                $0.comments.contains { $0.rawValue == "Auth changed accounts without signing out first." }
            }
            await store.receive(\.authUserChanged, nil) {
                $0.scene = .signIn(SignIn.State())
            }
            await store.finish()
            expectNoDifference(events.value, ["clearLocalData", "currentUser", "clearLocalData"])
        }

        // The loading state hides the sign in controls while the local data disappears
        @Test
        func signingOutSettlesBeforeTheSignInAppears() async {
            var state = AppFeature.State()
            state.scene = .home(Home.State(user: .mock))

            let clock = TestClock()
            await confirmation("Clears the local data") { clearsLocalData in
                let store = TestStore(initialState: state) {
                    AppFeature()
                } withDependencies: {
                    $0.continuousClock = clock
                    $0.expensesClient.clearLocalData = { clearsLocalData() }
                }

                await store.send(.authUserChanged(nil)) {
                    $0.isSignedOutSettling = true
                }
                #expect(store.state.isLoading)
                #expect(store.state.scene.is(\.home))

                await clock.advance(by: AppFeature.signedOutCoverDelay)
                await store.receive(\.signedOutCoverTimerElapsed) {
                    $0.scene = .signIn(SignIn.State())
                }
                #expect(store.state.isLoading)

                await clock.advance(by: AppFeature.signedOutSettleDelay)
                await store.receive(\.signedOutSettleTimerElapsed) {
                    $0.isSignedOutSettling = false
                }
                #expect(!store.state.isLoading)
                await store.finish()
            }
        }

        @Test
        func aSignOutCancelsTheCredentialCheck() async {
            let isCheckCanceled = LockIsolated(false)
            let isCheckRunning = LockIsolated(false)
            var state = AppFeature.State()
            state.scene = .home(Home.State(user: .mock))

            let clock = TestClock()
            let store = TestStore(initialState: state) {
                AppFeature()
            } withDependencies: {
                $0.authClient.appleUserID = { "apple-user" }
                $0.continuousClock = clock
                $0.expensesClient.clearLocalData = {}
                $0.signInWithAppleClient.credentialState = { _ in
                    await withTaskCancellationHandler {
                        isCheckRunning.setValue(true)
                        _ = try? await Task.never()
                    } onCancel: {
                        isCheckCanceled.setValue(true)
                    }
                    return .authorized
                }
            }

            await store.send(.appBecameActive)
            while !isCheckRunning.value {
                await Task.yield()
            }
            await store.send(.authUserChanged(nil)) {
                $0.isSignedOutSettling = true
            }

            await clock.advance(by: AppFeature.signedOutCoverDelay)
            await store.receive(\.signedOutCoverTimerElapsed) {
                $0.scene = .signIn(SignIn.State())
            }
            await clock.advance(by: AppFeature.signedOutSettleDelay)
            await store.receive(\.signedOutSettleTimerElapsed) {
                $0.isSignedOutSettling = false
            }
            await store.finish()
            #expect(isCheckCanceled.value)
        }

        // A late answer for the old user must not sign out the new one
        @Test
        func anAccountSwitchCancelsTheCredentialCheck() async {
            let isCheckCanceled = LockIsolated(false)
            let isCheckRunning = LockIsolated(false)
            var state = AppFeature.State()
            state.scene = .home(Home.State(user: .mock))

            let store = TestStore(initialState: state) {
                AppFeature()
            } withDependencies: {
                $0.authClient.appleUserID = { "apple-user" }
                $0.authClient.currentUser = { nil }
                $0.expensesClient.clearLocalData = {}
                $0.signInWithAppleClient.credentialState = { _ in
                    await withTaskCancellationHandler {
                        isCheckRunning.setValue(true)
                        _ = try? await Task.never()
                    } onCancel: {
                        isCheckCanceled.setValue(true)
                    }
                    return .revoked
                }
            }

            await store.send(.appBecameActive)
            while !isCheckRunning.value {
                await Task.yield()
            }
            await withKnownIssue {
                await store.send(.authUserChanged(AccountUser(email: "other@example.com", uid: "other-uid"))) {
                    $0.scene = nil
                }
            } matching: {
                $0.comments.contains { $0.rawValue == "Auth changed accounts without signing out first." }
            }
            await store.receive(\.authUserChanged, nil) {
                $0.scene = .signIn(SignIn.State())
            }
            await store.finish()
            #expect(isCheckCanceled.value)
        }

        // The sign-out timers of the old session must not hide the new one
        @Test
        func anAccountSwitchDuringTheSignOutCancelsTheTimers() async {
            let other = AccountUser(email: "other@example.com", uid: "other-uid")
            var state = AppFeature.State()
            state.scene = .home(Home.State(user: .mock))

            let clock = TestClock()
            let store = TestStore(initialState: state) {
                AppFeature()
            } withDependencies: {
                $0.authClient.appleUserID = { nil }
                $0.authClient.currentUser = { other }
                $0.continuousClock = clock
                $0.expensesClient.clearLocalData = {}
            }

            await store.send(.authUserChanged(nil)) {
                $0.isSignedOutSettling = true
            }
            await withKnownIssue {
                await store.send(.authUserChanged(other)) {
                    $0.isSignedOutSettling = false
                    $0.scene = nil
                }
            } matching: {
                $0.comments.contains { $0.rawValue == "Auth changed accounts without signing out first." }
            }
            await store.receive(\.authUserChanged, other) {
                $0.scene = .home(Home.State(user: other))
            }
            await clock.advance(by: AppFeature.signedOutCoverDelay + AppFeature.signedOutSettleDelay)
            await store.finish()
        }

        // The sign out is already in progress, so a second one would stop it
        @Test
        func theCredentialChecksAreIgnoredWhileSigningOut() async {
            var state = AppFeature.State()
            state.isSignedOutSettling = true
            state.scene = .home(Home.State(user: .mock))

            let store = TestStore(initialState: state) {
                AppFeature()
            }

            await store.send(.appBecameActive)
            await store.send(.appleCredentialRevoked)
        }

        // The sign-in scene does not hold a session, so it has nothing to check
        @Test
        func theCredentialChecksAreIgnoredOutsideTheHomeScene() async {
            var state = AppFeature.State()
            state.scene = .signIn(SignIn.State())

            let store = TestStore(initialState: state) {
                AppFeature()
            }

            await store.send(.appBecameActive)
            await store.send(.appleCredentialRevoked)
        }

        @Test
        func signingOutCancelsTheExpenseWritesInFlight() async {
            var home = Home.State(user: .mock)
            home.expenses.path.append(ExpenseDetail.State(expense: SharedReader(value: .rent)))
            let detailID = Array(home.expenses.path.ids)[0]
            var state = AppFeature.State()
            state.scene = .home(home)

            let pendingSave = LockIsolated<CheckedContinuation<Void, Never>?>(nil)
            let store = TestStore(initialState: state) {
                AppFeature()
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

        private struct DeletionFailure: Error {}

        private struct ExpensesFailure: Error {}
    }
}
