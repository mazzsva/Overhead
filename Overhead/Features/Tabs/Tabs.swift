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
    enum FailedOperation: Hashable {
        case deleteExpense
        case saveBudget
        case saveExpense
    }

    enum Tab: Hashable {
        case expenses
        case overview
        case settings
    }

    @ObservableState
    struct State: Equatable {
        var expenses: Expenses.State
        var failedOperations: Set<FailedOperation> = []
        @SharedReader(.hasDismissedWelcome) var hasDismissedWelcome
        var overview: Overview.State
        var selectedTab = Tab.overview
        var settings: Settings.State
        let user: User

        init(user: User, sessionOrigin: SessionOrigin = .restored) {
            let expenses = Expenses.State(user: user, sessionOrigin: sessionOrigin)
            self.expenses = expenses
            overview = Overview.State(expenses: SharedReader(expenses.$expenses), user: user)
            settings = Settings.State(user: user)
            self.user = user
        }

        var failureMessage: String {
            switch failedOperations {
            case [.deleteExpense]:
                return String(localized: "Your expense couldn't be deleted.")
            case [.saveBudget]:
                return String(localized: "Your income couldn't be saved.")
            case [.saveExpense]:
                return String(localized: "Your expense couldn't be saved.")
            default:
                return String(localized: "Some of your changes couldn't be saved.")
            }
        }

        var isDeletingAccount: Bool { settings.isDeletingAccount }

        var isLoadingFirstExpenses: Bool { expenses.isLoadingFirstExpenses }

        var isPresentingFailure: Bool {
            !failedOperations.isEmpty && !isPresentingAnythingElse
        }

        var isReauthenticating: Bool { settings.isReauthenticating }

        var sessionOrigin: SessionOrigin { expenses.sessionOrigin }

        private var isPresentingAnythingElse: Bool {
            expenses.isPresenting || overview.isPresenting || settings.isPresenting || isLoadingFirstExpenses
                || !hasDismissedWelcome
        }
    }

    enum Action {
        case expenses(Expenses.Action)
        case failurePresentationChanged(Bool)
        case overview(Overview.Action)
        case selectedTabChanged(Tab)
        case settings(Settings.Action)
    }

    var body: some Reducer<State, Action> {
        Scope(state: \.expenses, action: \.expenses) {
            Expenses()
        }
        Scope(state: \.overview, action: \.overview) {
            Overview()
        }
        Scope(state: \.settings, action: \.settings) {
            Settings()
        }
        Reduce { state, action in
            switch action {
            case .expenses(.delegate(.didFailToDelete)):
                state.failedOperations.insert(.deleteExpense)
                return .none

            case .expenses(.delegate(.didFailToSave)):
                state.failedOperations.insert(.saveExpense)
                return .none

            case .failurePresentationChanged(false):
                guard state.isPresentingFailure else { return .none }
                state.failedOperations.removeAll()
                return .none

            case .failurePresentationChanged(true):
                return .none

            case .overview(.delegate(.didFailToSaveBudget)):
                state.failedOperations.insert(.saveBudget)
                return .none

            case .overview(.delegate(.didSelectExpenses)):
                state.selectedTab = .expenses
                return .none

            case .expenses, .overview, .settings:
                return .none

            case .selectedTabChanged(let tab):
                state.selectedTab = tab
                return .none
            }
        }
    }
}
