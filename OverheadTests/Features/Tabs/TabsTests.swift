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
        func aFailedSaveShowsAnAlert() async {
            let state = makeReadyState()

            let store = TestStore(initialState: state) {
                Tabs()
            }

            await store.send(.home(.delegate(.didFailToSave))) {
                $0.failedEntryOperations = [.save]
            }
            #expect(store.state.isPresentingEntryFailure)
            expectNoDifference(store.state.entryFailureMessage, "Your entry couldn't be saved.")
        }

        @Test
        func differentFailuresShowACombinedMessage() async {
            let state = makeReadyState()

            let store = TestStore(initialState: state) {
                Tabs()
            }

            await store.send(.home(.delegate(.didFailToSave))) {
                $0.failedEntryOperations = [.save]
            }
            await store.send(.home(.delegate(.didFailToSave)))
            await store.send(.home(.delegate(.didFailToDelete))) {
                $0.failedEntryOperations = [.delete, .save]
            }
            expectNoDifference(
                store.state.entryFailureMessage,
                "Some of your changes couldn't be saved."
            )
        }

        @Test
        func dismissingTheAlertClearsTheFailures() async {
            var state = makeReadyState()
            state.failedEntryOperations = [.delete, .save]

            let store = TestStore(initialState: state) {
                Tabs()
            }

            await store.send(.entryFailurePresentationChanged(false)) {
                $0.failedEntryOperations = []
            }
        }

        @Test
        func aHiddenAlertKeepsTheFailures() async {
            var state = makeReadyState()
            state.failedEntryOperations = [.save]
            state.settings.alert = .signOutFailed

            let store = TestStore(initialState: state) {
                Tabs()
            }

            await store.send(.entryFailurePresentationChanged(false))
        }

        // A save that fails in the background must not interrupt the form on screen
        @Test
        func aFailedSaveWaitsForThePresentedForm() async {
            var state = makeReadyState()
            state.home.destination = .createEntry(EntryForm.State())

            let store = TestStore(initialState: state) {
                Tabs()
            }

            await store.send(.home(.delegate(.didFailToSave))) {
                $0.failedEntryOperations = [.save]
            }
            #expect(!store.state.isPresentingEntryFailure)

            await store.send(.home(.destination(.dismiss))) {
                $0.home.destination = nil
            }
            #expect(store.state.isPresentingEntryFailure)
        }

        // The deletion of one entry must not interrupt the creation of a different one
        @Test
        func aFailedDeletionWaitsForThePresentedForm() async {
            var state = makeReadyState()
            state.home.destination = .createEntry(EntryForm.State())

            let store = TestStore(initialState: state) {
                Tabs()
            }

            await store.send(.home(.delegate(.didFailToDelete))) {
                $0.failedEntryOperations = [.delete]
            }
            #expect(!store.state.isPresentingEntryFailure)

            await store.send(.home(.destination(.dismiss))) {
                $0.home.destination = nil
            }
            #expect(store.state.isPresentingEntryFailure)
            expectNoDifference(store.state.entryFailureMessage, "Your entry couldn't be deleted.")
        }

        @Test
        func aFailureWaitsForTheDetailPresentation() async {
            var state = makeReadyState()
            state.home.path.append(EntryDetail.State(entry: SharedReader(value: .blueMoon)))
            let detailID = Array(state.home.path.ids)[0]
            state.home.path[id: detailID]?.destination = .alert(.confirmDeletion)

            let store = TestStore(initialState: state) {
                Tabs()
            }

            await store.send(.home(.delegate(.didFailToSave))) {
                $0.failedEntryOperations = [.save]
            }
            #expect(!store.state.isPresentingEntryFailure)

            await store.send(.home(.path(.element(id: detailID, action: .destination(.dismiss))))) {
                $0.home.path[id: detailID]?.destination = nil
            }
            #expect(store.state.isPresentingEntryFailure)
        }

        @Test
        func aFailureWaitsForTheSettingsAlert() async {
            var state = makeReadyState()
            state.settings.alert = .confirmSignOut

            let store = TestStore(initialState: state) {
                Tabs()
            }

            await store.send(.home(.delegate(.didFailToSave))) {
                $0.failedEntryOperations = [.save]
            }
            #expect(!store.state.isPresentingEntryFailure)

            await store.send(.settings(.alert(.dismiss))) {
                $0.settings.alert = nil
            }
            #expect(store.state.isPresentingEntryFailure)
        }

        @Test
        func aFailureWaitsForTheAccountDeletion() {
            var state = makeReadyState()
            state.failedEntryOperations = [.save]

            state.settings.deletionStep = .deleting
            #expect(!state.isPresentingEntryFailure)

            state.settings.deletionStep = nil
            #expect(state.isPresentingEntryFailure)
        }

        @Test
        func aFailureWaitsForTheFirstEntries() {
            var state = makeReadyState()
            state.failedEntryOperations = [.save]

            state.home.$entries.withLock { $0 = nil }
            #expect(!state.isPresentingEntryFailure)

            state.home.$entries.withLock { $0 = [] }
            #expect(state.isPresentingEntryFailure)
        }

        @Test
        func aFailureWaitsForTheWelcome() {
            @Shared(.hasDismissedWelcome) var hasDismissedWelcome
            var state = makeReadyState()
            state.failedEntryOperations = [.save]

            $hasDismissedWelcome.withLock { $0 = false }
            #expect(!state.isPresentingEntryFailure)

            $hasDismissedWelcome.withLock { $0 = true }
            #expect(state.isPresentingEntryFailure)
        }

        private func makeReadyState() -> Tabs.State {
            @Shared(.hasDismissedWelcome) var hasDismissedWelcome
            $hasDismissedWelcome.withLock { $0 = true }
            let state = Tabs.State(user: .mock)
            state.home.$entries.withLock { $0 = [] }
            return state
        }
    }
}
