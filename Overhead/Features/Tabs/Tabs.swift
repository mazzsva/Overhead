//
//  Tabs.swift
//  Overhead
//
//  Created by Lorenzo Mazzarotto on 01/10/26.
//

import ComposableArchitecture
import Foundation
import os

@Reducer
struct Tabs {
    enum ExpenseOperation: Hashable {
        case delete
        case save
    }

    enum Tab: Hashable {
        case expenses
        case overview
        case settings
    }

    @ObservableState
    struct State: Equatable {
        @Shared var defaultCurrencyCode: String?
        var expenses: Expenses.State
        var failedExpenseOperations: Set<ExpenseOperation> = []
        @SharedReader(.hasDismissedWelcome) var hasDismissedWelcome
        var selectedTab = Tab.overview
        var settings: Settings.State
        let user: User

        init(user: User, sessionOrigin: SessionOrigin = .restored) {
            _defaultCurrencyCode = Shared(wrappedValue: nil, .defaultCurrencyCode(uid: user.uid))
            expenses = Expenses.State(user: user, sessionOrigin: sessionOrigin)
            settings = Settings.State(user: user)
            self.user = user
        }

        var expenseFailureMessage: String {
            switch failedExpenseOperations {
            case [.delete]:
                return String(localized: "Your expense couldn't be deleted.")
            case [.save]:
                return String(localized: "Your expense couldn't be saved.")
            default:
                return String(localized: "Some of your changes couldn't be saved.")
            }
        }

        var isDeletingAccount: Bool { settings.isDeletingAccount }

        var isLoadingFirstExpenses: Bool { expenses.isLoadingFirstExpenses }

        var isPresentingExpenseFailure: Bool {
            !failedExpenseOperations.isEmpty && !isPresentingAnythingElse
        }

        var isReauthenticating: Bool { settings.isReauthenticating }

        var sessionOrigin: SessionOrigin { expenses.sessionOrigin }

        private var isPresentingAnythingElse: Bool {
            expenses.isPresenting || settings.isPresenting || isLoadingFirstExpenses || !hasDismissedWelcome
        }
    }

    enum Action {
        case defaultCurrencyCodeUpdated(String?)
        case expenseFailurePresentationChanged(Bool)
        case expenses(Expenses.Action)
        case selectedTabChanged(Tab)
        case settings(Settings.Action)
        case task
    }

    enum CancelID {
        case profileSubscription
    }

    @Dependency(\.continuousClock) var clock
    @Dependency(\.profileClient) var profileClient

    var body: some Reducer<State, Action> {
        Scope(state: \.expenses, action: \.expenses) {
            Expenses()
        }
        Scope(state: \.settings, action: \.settings) {
            Settings()
        }
        Reduce { state, action in
            switch action {
            case .defaultCurrencyCodeUpdated(let currencyCode):
                state.$defaultCurrencyCode.withLock { $0 = currencyCode }
                return .none

            case .expenseFailurePresentationChanged(false):
                guard state.isPresentingExpenseFailure else { return .none }
                state.failedExpenseOperations.removeAll()
                return .none

            case .expenseFailurePresentationChanged(true):
                return .none

            case .expenses(.delegate(.didFailToDelete)):
                state.failedExpenseOperations.insert(.delete)
                return .none

            case .expenses(.delegate(.didFailToSave)):
                state.failedExpenseOperations.insert(.save)
                return .none

            case .expenses, .settings:
                return .none

            case .selectedTabChanged(let tab):
                state.selectedTab = tab
                return .none

            case .task:
                return subscribeToProfile(uid: state.user.uid)
            }
        }
    }

    private func subscribeToProfile(uid: String) -> Effect<Action> {
        .run { send in
            while true {
                do {
                    for try await currencyCode in await profileClient.defaultCurrencyCode(uid: uid) {
                        await send(.defaultCurrencyCodeUpdated(currencyCode))
                    }
                    return
                } catch {
                    logger.error("Profile stream failed: \(error, privacy: .public)")
                    try await clock.sleep(for: .seconds(5))
                }
            }
        }
        .cancellable(id: CancelID.profileSubscription, cancelInFlight: true)
    }
}

private let logger = Logger(category: "Tabs")
