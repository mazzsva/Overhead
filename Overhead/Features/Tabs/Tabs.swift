//
//  Tabs.swift
//  Overhead
//
//  Created by Lorenzo Mazzarotto on 01/10/26.
//

import ComposableArchitecture
import Foundation

@Reducer
struct Tabs {
    enum ExpenseOperation: Hashable {
        case delete
        case save
    }

    enum Tab: Hashable {
        case home
        case overview
        case settings
    }

    @ObservableState
    struct State: Equatable {
        var failedExpenseOperations: Set<ExpenseOperation> = []
        @SharedReader(.hasDismissedWelcome) var hasDismissedWelcome
        var home: Home.State
        var selectedTab = Tab.overview
        var settings: Settings.State
        let user: User

        init(user: User, sessionOrigin: Home.State.SessionOrigin = .restored) {
            home = Home.State(user: user, sessionOrigin: sessionOrigin)
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

        var isLoadingFirstExpenses: Bool { home.isLoadingFirstExpenses }

        var isPresentingExpenseFailure: Bool {
            !failedExpenseOperations.isEmpty && !isPresentingAnythingElse
        }

        var isReauthenticating: Bool { settings.isReauthenticating }

        var sessionOrigin: Home.State.SessionOrigin { home.sessionOrigin }

        private var isPresentingAnythingElse: Bool {
            home.isPresenting || settings.isPresenting || isLoadingFirstExpenses || !hasDismissedWelcome
        }
    }

    enum Action {
        case expenseFailurePresentationChanged(Bool)
        case home(Home.Action)
        case selectedTabChanged(Tab)
        case settings(Settings.Action)
    }

    var body: some Reducer<State, Action> {
        Scope(state: \.home, action: \.home) {
            Home()
        }
        Scope(state: \.settings, action: \.settings) {
            Settings()
        }
        Reduce { state, action in
            switch action {
            case .expenseFailurePresentationChanged(false):
                guard state.isPresentingExpenseFailure else { return .none }
                state.failedExpenseOperations.removeAll()
                return .none

            case .expenseFailurePresentationChanged(true):
                return .none

            case .home(.delegate(.didFailToDelete)):
                state.failedExpenseOperations.insert(.delete)
                return .none

            case .home(.delegate(.didFailToSave)):
                state.failedExpenseOperations.insert(.save)
                return .none

            case .home, .settings:
                return .none

            case .selectedTabChanged(let tab):
                state.selectedTab = tab
                return .none
            }
        }
    }
}
