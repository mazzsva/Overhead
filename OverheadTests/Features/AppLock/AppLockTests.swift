//
//  AppLockTests.swift
//  OverheadTests
//
//  Created by Lorenzo Mazzarotto on 30/10/26.
//

import ComposableArchitecture
import Testing

@testable import Overhead

extension BaseSuite {
    @Suite
    @MainActor
    struct AppLockTests {
        @Test
        func leavingTheAppLocksItWhenTheLockIsOn() async {
            @Shared(.locksApp) var locksApp = true
            var state = AppLock.State()
            state.isLocked = false
            state.promptsWhenActive = false
            let store = TestStore(initialState: state) {
                AppLock()
            }

            await store.send(.sceneBecameBackground) {
                $0.isLocked = true
                $0.promptsWhenActive = true
            }
        }

        @Test
        func signingOutUnlocksTheApp() async {
            @Shared(.locksApp) var locksApp = true
            var state = AppLock.State()
            state.isLocked = true
            let store = TestStore(initialState: state) {
                AppLock()
            }

            await store.send(.signedOut) {
                $0.isLocked = false
            }
        }

        @Test
        func leavingTheAppDoesNothingWhenTheLockIsOff() async {
            @Shared(.locksApp) var locksApp = false
            let store = TestStore(initialState: AppLock.State()) {
                AppLock()
            }

            await store.send(.sceneBecameBackground)
        }

        @Test
        func returningToALockedAppAsksOnceAndUnlocksOnSuccess() async {
            @Shared(.locksApp) var locksApp = true
            await confirmation("Asks for authentication") { asks in
                var state = AppLock.State()
                state.isLocked = true
                state.promptsWhenActive = true
                let store = TestStore(initialState: state) {
                    AppLock()
                } withDependencies: {
                    $0.biometricsClient.authenticate = { _ in
                        asks()
                        return true
                    }
                }

                await store.send(.sceneBecameActive) {
                    $0.promptsWhenActive = false
                    $0.$isAuthenticating.withLock { $0 = true }
                }
                await store.receive(\.authenticationResponse) {
                    $0.isLocked = false
                    $0.$isAuthenticating.withLock { $0 = false }
                }
            }
        }

        @Test
        func aCancelledPromptKeepsTheAppLockedAndDoesNotAskAgain() async {
            @Shared(.locksApp) var locksApp = true
            var state = AppLock.State()
            state.isLocked = true
            state.promptsWhenActive = true
            let store = TestStore(initialState: state) {
                AppLock()
            } withDependencies: {
                $0.biometricsClient.authenticate = { _ in false }
            }

            await store.send(.sceneBecameActive) {
                $0.promptsWhenActive = false
                $0.$isAuthenticating.withLock { $0 = true }
            }
            await store.receive(\.authenticationResponse) {
                $0.$isAuthenticating.withLock { $0 = false }
            }
            await store.send(.sceneBecameInactive) {
                $0.isInactive = true
            }
            await store.send(.sceneBecameActive) {
                $0.isInactive = false
            }
        }

        @Test
        func theUnlockButtonAsksForAuthentication() async {
            @Shared(.locksApp) var locksApp = true
            var state = AppLock.State()
            state.isLocked = true
            let store = TestStore(initialState: state) {
                AppLock()
            } withDependencies: {
                $0.biometricsClient.authenticate = { _ in true }
            }

            await store.send(.unlockButtonTapped) {
                $0.$isAuthenticating.withLock { $0 = true }
            }
            await store.receive(\.authenticationResponse) {
                $0.isLocked = false
                $0.$isAuthenticating.withLock { $0 = false }
            }
        }

        @Test
        func theAppIsCoveredWhileInactive() async {
            @Shared(.locksApp) var locksApp = true
            var state = AppLock.State()
            state.isLocked = false
            let store = TestStore(initialState: state) {
                AppLock()
            }

            await store.send(.sceneBecameInactive) {
                $0.isInactive = true
            }
            #expect(store.state.isCovering)
        }

        @Test
        func theAppIsNotCoveredWhileTheSystemPromptIsOnScreen() async {
            @Shared(.locksApp) var locksApp = true
            @Shared(.isAuthenticatingWithBiometrics) var isAuthenticating = true
            var state = AppLock.State()
            state.isLocked = false
            let store = TestStore(initialState: state) {
                AppLock()
            }

            await store.send(.sceneBecameInactive) {
                $0.isInactive = true
                $0.isInactiveForAuthentication = true
            }
            $isAuthenticating.withLock { $0 = false }
            #expect(!store.state.isCovering)

            await store.send(.sceneBecameActive) {
                $0.isInactive = false
                $0.isInactiveForAuthentication = false
            }
        }

        @Test
        func theUnlockButtonIsEnabledOnlyWhenItCanAskForAuthentication() {
            @Shared(.isAuthenticatingWithBiometrics) var isAuthenticating = false
            var state = AppLock.State()
            state.isLocked = true
            #expect(state.canUnlock)

            state.isInactive = true
            #expect(!state.canUnlock)

            state.isInactive = false
            $isAuthenticating.withLock { $0 = true }
            #expect(!state.canUnlock)

            $isAuthenticating.withLock { $0 = false }
            state.isLocked = false
            #expect(!state.canUnlock)
        }

        @Test
        func theUnlockButtonDoesNothingWhileTheAppIsInactive() async {
            @Shared(.locksApp) var locksApp = true
            var state = AppLock.State()
            state.isLocked = true
            state.isInactive = true
            let store = TestStore(initialState: state) {
                AppLock()
            }

            await store.send(.unlockButtonTapped)
        }
    }
}
