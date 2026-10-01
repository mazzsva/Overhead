//
//  TabsTests.swift
//  OverheadTests
//
//  Created by Lorenzo Mazzarotto on 01/10/26.
//

import ComposableArchitecture
import CustomDump
import Testing

@testable import Overhead

extension BaseSuite {
    @Suite
    @MainActor
    struct TabsTests {
        @Test
        func everyTabStartsWithTheSessionUser() {
            let state = Tabs.State(user: .mock, sessionOrigin: .freshSignIn(isNewAccount: true))

            expectNoDifference(
                state.home,
                Home.State(user: .mock, sessionOrigin: .freshSignIn(isNewAccount: true))
            )
            expectNoDifference(state.selectedTab, .home)
            expectNoDifference(state.settings, Settings.State(user: .mock))
        }

        @Test
        func theTaskStartsTheHomeTaskForTheWholeSession() async {
            let entries = AsyncThrowingStream<EntriesSnapshot, any Error>.makeStream()

            let store = TestStore(initialState: Tabs.State(user: .mock)) {
                Tabs()
            } withDependencies: {
                $0.entriesClient.entries = { _ in entries.stream }
                $0.networkMonitorClient.connectivityChanges = { AsyncStream { _ in } }
            }

            let task = await store.send(.task)
            await store.receive(\.home.task)

            entries.continuation.yield(.mock)
            await store.receive(\.home.entriesUpdated) {
                $0.home.$entries.withLock { $0 = IdentifiedArray(uniqueElements: Entry.mocks) }
                $0.home.isSyncing = false
            }

            await store.send(.selectedTabChanged(.settings)) {
                $0.selectedTab = .settings
            }
            entries.continuation.yield(.empty)
            await store.receive(\.home.entriesUpdated) {
                $0.home.$entries.withLock { $0 = [] }
            }

            await task.cancel()
            await store.finish()
        }

        @Test
        func theAccountDeletionContinuesAfterATabChange() async {
            let reauthentication = AsyncStream<Void>.makeStream()
            var state = Tabs.State(user: .mock)
            state.selectedTab = .settings
            state.settings.alert = .confirmAccountDeletion

            let store = TestStore(initialState: state) {
                Tabs()
            } withDependencies: {
                $0.authClient.deleteAccount = {}
                $0.authClient.reauthenticate = { _ in
                    for await _ in reauthentication.stream { return }
                }
                $0.authClient.revokeAppleToken = { _ in }
                $0.continuousClock = TestClock()
                $0.entriesClient.deleteAll = { _ in }
                $0.signInWithAppleClient.requestCredential = { .mock }
            }

            await store.send(.settings(.alert(.presented(.confirmAccountDeletion)))) {
                $0.settings.alert = nil
                $0.settings.deletionStep = .reauthenticating
            }
            await store.receive(\.settings.appleCredentialReceived) {
                $0.settings.deletionStep = .deleting
            }

            await store.send(.selectedTabChanged(.home)) {
                $0.selectedTab = .home
            }

            reauthentication.continuation.yield()
            await store.receive(\.settings.entriesDeleted) {
                $0.settings.deletionStep = .entriesDeleted
            }
            await store.receive(\.settings.appleCredentialRevoked) {
                $0.settings.deletionStep = .credentialRevoked
            }
            await store.finish()
        }
    }
}
