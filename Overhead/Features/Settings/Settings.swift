//
//  Settings.swift
//  Overhead
//
//  Created by Lorenzo Mazzarotto on 22/07/26.
//

import ComposableArchitecture
import Foundation
import os

@Reducer
struct Settings {
    enum AccountDeletionError: Error {
        case missingAuthorizationCode
        case timedOut
    }

    enum Alert: Equatable {
        case confirmAccountDeletion
        case confirmSignOut
    }

    enum DeletionStep: Equatable {
        case budgetDeleted
        case credentialRevoked
        case deleting
        case reauthenticating
    }

    @ObservableState
    struct State: Equatable {
        @Presents var alert: AlertState<Settings.Alert>?
        var biometryType: BiometryType?
        @Shared(.currency) var currency
        var deletionStep: DeletionStep?
        @Shared(.isAuthenticatingWithBiometrics) var isAuthenticatingWithBiometrics
        @Shared(.locksApp) var locksApp
        #if DEBUG
        @Shared(.showsWelcomeAtNextLaunch) var showsWelcomeAtNextLaunch
        #endif
        let user: User

        var isDeletingAccount: Bool { deletionStep != nil }

        var isPresenting: Bool { alert != nil || isDeletingAccount }

        var isReauthenticating: Bool { deletionStep == .reauthenticating }
    }

    enum Action {
        case accountDeletionFailed(any Error)
        case alert(PresentationAction<Alert>)
        case appleCredentialReceived
        case appleCredentialRevoked
        case budgetDeleted
        case currencyPickerChanged(Currency)
        case currencyUpdated(CurrencySnapshot)
        #if DEBUG
        case debugAddMockExpensesButtonTapped
        case debugDeleteAllExpensesButtonTapped
        case debugResetWelcomeToggleChanged(Bool)
        #endif
        case delegate(Delegate)
        case deleteAccountButtonTapped
        case lockAuthenticationResponse(isOn: Bool, Result<Bool, any Error>)
        case lockToggleChanged(Bool)
        case signOutButtonTapped
        case signOutFailed(any Error)
        case task

        @CasePathable
        enum Delegate {
            case didFailToSaveCurrency
        }
    }

    enum CancelID {
        case currencySubscription
    }

    @Dependency(\.authClient) var authClient
    @Dependency(\.biometricsClient) var biometricsClient
    @Dependency(\.budgetClient) var budgetClient
    @Dependency(\.continuousClock) var clock
    @Dependency(\.currencyClient) var currencyClient
    @Dependency(\.expensesClient) var expensesClient
    @Dependency(\.locale) var locale
    @Dependency(\.signInWithAppleClient) var signInWithAppleClient

    var body: some Reducer<State, Action> {
        Reduce { state, action in
            switch action {
            case .accountDeletionFailed(let error):
                guard state.deletionStep != .credentialRevoked else {
                    logger.error(
                        "Account deletion failed after the revoke attempt; signing out: \(error, privacy: .public)")
                    return signOut()
                }
                let hasDeletedUserData = state.deletionStep == .budgetDeleted
                state.deletionStep = nil
                if !error.isSignInWithAppleCancellation {
                    logger.error("Account deletion failed: \(error, privacy: .public)")
                    state.alert = hasDeletedUserData ? .accountDeletionUnfinished : .accountDeletionFailed
                }
                return .none

            case .alert(.presented(.confirmAccountDeletion)):
                state.deletionStep = .reauthenticating
                return deleteAccount(uid: state.user.uid)

            case .alert(.presented(.confirmSignOut)):
                return signOut()

            case .alert:
                return .none

            case .appleCredentialReceived:
                state.deletionStep = .deleting
                return .none

            case .appleCredentialRevoked:
                state.deletionStep = .credentialRevoked
                return .none

            case .budgetDeleted:
                state.deletionStep = .budgetDeleted
                return .none

            case .currencyPickerChanged(let currency):
                state.$currency.withLock { $0 = currency }
                let uid = state.user.uid
                return .run { _ in
                    try await currencyClient.save(currency: currency, uid: uid)
                } catch: { error, send in
                    logger.error("Saving the currency failed: \(error, privacy: .public)")
                    await send(.delegate(.didFailToSaveCurrency))
                }

            case .currencyUpdated(.known(let currency)):
                state.$currency.withLock { $0 = currency ?? Currency(locale: locale) }
                return .none

            case .currencyUpdated(.unknown):
                return .none

            #if DEBUG
            case .debugAddMockExpensesButtonTapped:
                return addMockExpenses(uid: state.user.uid)

            case .debugDeleteAllExpensesButtonTapped:
                return deleteAllExpenses(uid: state.user.uid)

            case .debugResetWelcomeToggleChanged(let isOn):
                state.$showsWelcomeAtNextLaunch.withLock { $0 = isOn }
                return .none
            #endif

            case .delegate:
                return .none

            case .deleteAccountButtonTapped:
                guard !state.isDeletingAccount else { return .none }
                state.alert = .confirmAccountDeletion
                return .none

            case .lockAuthenticationResponse(let isOn, .success(true)):
                state.$isAuthenticatingWithBiometrics.withLock { $0 = false }
                state.$locksApp.withLock { $0 = isOn }
                return .none

            case .lockAuthenticationResponse(_, .success(false)):
                state.$isAuthenticatingWithBiometrics.withLock { $0 = false }
                return .none

            case .lockAuthenticationResponse(_, .failure(let error)):
                state.$isAuthenticatingWithBiometrics.withLock { $0 = false }
                logger.error("Confirming the app lock change failed: \(error, privacy: .public)")
                return .none

            case .lockToggleChanged(let isOn):
                guard !state.isAuthenticatingWithBiometrics, state.biometryType != nil else { return .none }
                state.$isAuthenticatingWithBiometrics.withLock { $0 = true }
                return .run { send in
                    await send(
                        .lockAuthenticationResponse(
                            isOn: isOn,
                            Result {
                                try await biometricsClient.authenticate(
                                    isOn
                                        ? String(localized: "Turn on the Overhead lock.")
                                        : String(localized: "Turn off the Overhead lock.")
                                )
                            }
                        )
                    )
                }

            case .signOutButtonTapped:
                guard !state.isDeletingAccount else { return .none }
                state.alert = .confirmSignOut
                return .none

            case .signOutFailed(let error):
                state.deletionStep = nil
                logger.error("Sign out failed: \(error, privacy: .public)")
                state.alert = .signOutFailed
                return .none

            case .task:
                state.biometryType = biometricsClient.biometryType()
                return subscribeToCurrency(uid: state.user.uid)
            }
        }
        .ifLet(\.$alert, action: \.alert)
    }

    #if DEBUG
    private func addMockExpenses(uid: String) -> Effect<Action> {
        .run { _ in
            for expense in Expense.mocks {
                try await expensesClient.save(expense: expense, uid: uid)
            }
        } catch: { error, _ in
            logger.error("Adding the mock expenses failed: \(error, privacy: .public)")
        }
    }

    private func deleteAllExpenses(uid: String) -> Effect<Action> {
        .run { _ in
            try await expensesClient.deleteAll(uid: uid)
        } catch: { error, _ in
            logger.error("Deleting all the expenses failed: \(error, privacy: .public)")
        }
    }
    #endif

    private func deleteAccount(uid: String) -> Effect<Action> {
        .run { send in
            let credential = try await signInWithAppleClient.requestCredential()
            guard let authorizationCode = credential.authorizationCode else {
                throw AccountDeletionError.missingAuthorizationCode
            }
            await send(.appleCredentialReceived)
            try await withThrowingTaskGroup(of: Void.self) { group in
                group.addTask {
                    try await clock.sleep(for: .seconds(60))
                    throw AccountDeletionError.timedOut
                }
                group.addTask {
                    try await authClient.reauthenticate(credential: credential)
                    try Task.checkCancellation()
                    try await budgetClient.delete(uid: uid)
                    await send(.budgetDeleted)
                    try await expensesClient.deleteAll(uid: uid)
                    try Task.checkCancellation()
                    try await authClient.revokeAppleToken(authorizationCode: authorizationCode)
                    await send(.appleCredentialRevoked)
                    try Task.checkCancellation()
                    try await authClient.deleteAccount()
                }
                try await group.next()
                group.cancelAll()
            }
        } catch: { error, send in
            await send(.accountDeletionFailed(error))
        }
    }

    private func signOut() -> Effect<Action> {
        .run { _ in
            try await authClient.signOut()
        } catch: { error, send in
            await send(.signOutFailed(error))
        }
    }

    private func subscribeToCurrency(uid: String) -> Effect<Action> {
        .run { send in
            while true {
                do {
                    let snapshots = await currencyClient.currency(uid: uid)
                    for try await snapshot in snapshots {
                        await send(.currencyUpdated(snapshot))
                    }
                    return
                } catch {
                    logger.error("Currency stream failed: \(error, privacy: .public)")
                }
                try await clock.sleep(for: .seconds(5))
            }
        }
        .cancellable(id: CancelID.currencySubscription, cancelInFlight: true)
    }
}

extension AlertState where Action == Settings.Alert {
    static let accountDeletionFailed = AlertState {
        TextState("Something Went Wrong")
    } message: {
        TextState("Your account couldn't be deleted.")
    }

    static let accountDeletionUnfinished = AlertState {
        TextState("Something Went Wrong")
    } message: {
        TextState("Your account couldn't be fully deleted.")
    }

    static let confirmAccountDeletion = AlertState {
        TextState("Delete Account")
    } actions: {
        ButtonState(role: .destructive, action: .confirmAccountDeletion) {
            TextState("Delete")
        }
        ButtonState(role: .cancel) {
            TextState("Cancel")
        }
    } message: {
        TextState("Your account and all your data will be permanently deleted. Are you sure?")
    }

    static let confirmSignOut = AlertState {
        TextState("Sign Out")
    } actions: {
        ButtonState(role: .destructive, action: .confirmSignOut) {
            TextState("Sign Out")
        }
        ButtonState(role: .cancel) {
            TextState("Cancel")
        }
    } message: {
        TextState("Are you sure you want to sign out?")
    }

    static let signOutFailed = AlertState {
        TextState("Something Went Wrong")
    } message: {
        TextState("You couldn't be signed out.")
    }
}

private let logger = Logger(category: "Settings")
