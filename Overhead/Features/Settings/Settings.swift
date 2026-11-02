//
//  Settings.swift
//  Overhead
//
//  Created by Lorenzo Mazzarotto on 22/07/26.
//

import AccountKit
import ComposableArchitecture
import Foundation
import os

@Reducer
struct Settings {
    @ObservableState
    struct State: Equatable {
        var account = AccountSettings.State()
        @Shared(.currency) var currency
        #if DEBUG
        @Shared(.showsWelcomeAtNextLaunch) var showsWelcomeAtNextLaunch
        #endif
        let user: AccountUser

        var isPresenting: Bool { account.alert != nil }
    }

    enum Action {
        case account(AccountSettings.Action)
        case currencyPickerChanged(Currency)
        case currencyUpdated(CurrencySnapshot)
        #if DEBUG
        case debugAddMockExpensesButtonTapped
        case debugDeleteAllExpensesButtonTapped
        case debugResetWelcomeToggleChanged(Bool)
        #endif
        case delegate(Delegate)
        case task

        @CasePathable
        enum Delegate {
            case didFailToSaveCurrency
        }
    }

    enum CancelID {
        case currencySubscription
    }

    @Dependency(\.continuousClock) var clock
    @Dependency(\.currencyClient) var currencyClient
    #if DEBUG
    @Dependency(\.expensesClient) var expensesClient
    #endif
    @Dependency(\.locale) var locale

    var body: some Reducer<State, Action> {
        Scope(state: \.account, action: \.account) {
            AccountSettings()
        }
        Reduce { state, action in
            switch action {
            case .account:
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

            case .task:
                return subscribeToCurrency(uid: state.user.uid)
            }
        }
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

private let logger = Logger(category: "Settings")
