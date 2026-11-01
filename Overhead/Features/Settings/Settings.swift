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
    enum Alert: Equatable {
        case confirmAccountDeletion
        case confirmSignOut
    }

    @Reducer
    enum Destination {
        case alert(AlertState<Settings.Alert>)
    }

    @ObservableState
    struct State: Equatable {
        var biometryType: BiometryType?
        @Shared(.currency) var currency
        @Presents var destination: Destination.State?
        @Shared(.hidesAmounts) var hidesAmounts
        @Shared(.isAuthenticatingWithBiometrics) var isAuthenticatingWithBiometrics
        @Shared(.locksApp) var locksApp
        #if DEBUG
        @Shared(.showsWelcomeAtNextLaunch) var showsWelcomeAtNextLaunch
        #endif
        let user: User

        var isPresenting: Bool { destination != nil }
    }

    enum Action {
        case currencyPickerChanged(Currency)
        case currencyUpdated(CurrencySnapshot)
        #if DEBUG
        case debugAddMockExpensesButtonTapped
        case debugDeleteAllExpensesButtonTapped
        case debugResetWelcomeToggleChanged(Bool)
        #endif
        case delegate(Delegate)
        case deleteAccountButtonTapped
        case destination(PresentationAction<Destination.Action>)
        case hidesAmountsToggleChanged(Bool)
        case lockAuthenticationResponse(isOn: Bool, Result<Bool, any Error>)
        case lockToggleChanged(Bool)
        case signOutButtonTapped
        case signOutFailed(any Error)
        case task

        @CasePathable
        enum Delegate {
            case didConfirmAccountDeletion
            case didFailToSaveCurrency
        }
    }

    enum CancelID {
        case currencySubscription
    }

    @Dependency(\.authClient) var authClient
    @Dependency(\.biometricsClient) var biometricsClient
    @Dependency(\.continuousClock) var clock
    @Dependency(\.currencyClient) var currencyClient
    #if DEBUG
    @Dependency(\.expensesClient) var expensesClient
    #endif
    @Dependency(\.hapticsClient) var hapticsClient
    @Dependency(\.locale) var locale

    var body: some Reducer<State, Action> {
        Reduce { state, action in
            switch action {
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
                state.destination = .alert(.confirmAccountDeletion)
                return .none

            case .destination(.presented(.alert(.confirmAccountDeletion))):
                return .send(.delegate(.didConfirmAccountDeletion))

            case .destination(.presented(.alert(.confirmSignOut))):
                return .run { _ in
                    try await authClient.signOut()
                } catch: { error, send in
                    await send(.signOutFailed(error))
                }

            case .destination:
                return .none

            case .hidesAmountsToggleChanged(let hidesAmounts):
                state.$hidesAmounts.withLock { $0 = hidesAmounts }
                return .run { _ in await hapticsClient.impact() }

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
                state.destination = .alert(.confirmSignOut)
                return .none

            case .signOutFailed(let error):
                logger.error("Sign out failed: \(error, privacy: .public)")
                state.destination = .alert(.signOutFailed)
                return .none

            case .task:
                state.biometryType = biometricsClient.biometryType()
                return subscribeToCurrency(uid: state.user.uid)
            }
        }
        .ifLet(\.$destination, action: \.destination)
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

extension Settings.Destination.State: Equatable {}

extension AlertState where Action == Settings.Alert {
    static func accountDeletionFailed(_ failure: AccountDeletion.Failure) -> AlertState {
        AlertState {
            TextState("Something Went Wrong")
        } message: {
            switch failure {
            case .connectionFailed:
                TextState("Your account couldn't be deleted. Check your connection and try again.")
            case .notDeleted:
                TextState("Your account couldn't be deleted.")
            case .notFullyDeleted:
                TextState("Your account couldn't be fully deleted.")
            case .notSignedOut:
                TextState("You couldn't be signed out.")
            }
        }
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
