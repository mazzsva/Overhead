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
        var isPresentingAbout = false
        let user: AccountUser

        var isPresenting: Bool { account.alert != nil || isPresentingAbout }
    }

    enum Action {
        case aboutPresentationChanged(Bool)
        case account(AccountSettings.Action)
        case currencyPickerChanged(Currency)
        case currencyUpdated(CurrencySnapshot)
        case delegate(Delegate)
        case infoButtonTapped
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
    @Dependency(\.locale) var locale

    var body: some Reducer<State, Action> {
        Scope(state: \.account, action: \.account) {
            AccountSettings()
        }
        Reduce { state, action in
            switch action {
            case .aboutPresentationChanged(let isPresenting):
                state.isPresentingAbout = isPresenting
                return .none

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

            case .delegate:
                return .none

            case .infoButtonTapped:
                state.isPresentingAbout = true
                return .none

            case .task:
                return subscribeToCurrency(uid: state.user.uid)
            }
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

private let logger = Logger(category: "Settings")
