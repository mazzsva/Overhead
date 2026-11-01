//
//  AppLock.swift
//  Overhead
//
//  Created by Lorenzo Mazzarotto on 30/10/26.
//

import ComposableArchitecture
import Foundation
import os

@Reducer
struct AppLock {
    @ObservableState
    struct State: Equatable {
        var isInactive = false
        var isInactiveForAuthentication = false
        var isLocked = false
        var promptsWhenActive = false
        @Shared(.isAuthenticatingWithBiometrics) var isAuthenticating
        @Shared(.locksApp) var locksApp

        init() {
            isLocked = locksApp
            promptsWhenActive = locksApp
        }

        var canUnlock: Bool { isLocked && !isInactive && !isAuthenticating }

        var isCovering: Bool {
            guard locksApp else { return false }
            return isLocked || (isInactive && !isInactiveForAuthentication)
        }
    }

    enum Action {
        case authenticationResponse(Result<Bool, any Error>)
        case sceneBecameActive
        case sceneBecameBackground
        case sceneBecameInactive
        case signedOut
        case unlockButtonTapped
    }

    @Dependency(\.biometricsClient) var biometricsClient

    var body: some Reducer<State, Action> {
        Reduce { state, action in
            switch action {
            case .authenticationResponse(.success(let isAuthenticated)):
                state.$isAuthenticating.withLock { $0 = false }
                if isAuthenticated {
                    state.isLocked = false
                }
                return .none

            case .authenticationResponse(.failure(let error)):
                state.$isAuthenticating.withLock { $0 = false }
                logger.error("Unlocking failed: \(error, privacy: .public)")
                return .none

            case .sceneBecameActive:
                state.isInactive = false
                state.isInactiveForAuthentication = false
                guard state.locksApp, state.isLocked, state.promptsWhenActive else { return .none }
                state.promptsWhenActive = false
                return authenticate(&state)

            case .sceneBecameBackground:
                guard state.locksApp else { return .none }
                state.isInactive = false
                state.isLocked = true
                state.promptsWhenActive = true
                return .none

            case .sceneBecameInactive:
                state.isInactive = true
                state.isInactiveForAuthentication = state.isAuthenticating
                return .none

            case .signedOut:
                state.isLocked = false
                return .none

            case .unlockButtonTapped:
                guard state.canUnlock else { return .none }
                return authenticate(&state)
            }
        }
    }

    private func authenticate(_ state: inout State) -> Effect<Action> {
        guard !state.isAuthenticating else { return .none }
        state.$isAuthenticating.withLock { $0 = true }
        return .run { send in
            await send(
                .authenticationResponse(
                    Result { try await biometricsClient.authenticate(String(localized: "Unlock Overhead.")) }
                )
            )
        }
    }
}

private let logger = Logger(category: "AppLock")
