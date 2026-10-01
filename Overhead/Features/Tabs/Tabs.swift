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
    enum EntryOperation: Hashable {
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
        var failedEntryOperations: Set<EntryOperation> = []
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

        var entryFailureMessage: String {
            switch failedEntryOperations {
            case [.delete]:
                return String(localized: "Your entry couldn't be deleted.")
            case [.save]:
                return String(localized: "Your entry couldn't be saved.")
            default:
                return String(localized: "Some of your changes couldn't be saved.")
            }
        }

        var isDeletingAccount: Bool { settings.isDeletingAccount }

        var isLoadingFirstEntries: Bool { home.isLoadingFirstEntries }

        var isPresentingEntryFailure: Bool {
            !failedEntryOperations.isEmpty && !isPresentingAnythingElse
        }

        var isReauthenticating: Bool { settings.isReauthenticating }

        var sessionOrigin: Home.State.SessionOrigin { home.sessionOrigin }

        private var isPresentingAnythingElse: Bool {
            home.isPresenting || settings.isPresenting || isLoadingFirstEntries || !hasDismissedWelcome
        }
    }

    enum Action {
        case entryFailurePresentationChanged(Bool)
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
            case .entryFailurePresentationChanged(false):
                guard state.isPresentingEntryFailure else { return .none }
                state.failedEntryOperations.removeAll()
                return .none

            case .entryFailurePresentationChanged(true):
                return .none

            case .home(.delegate(.didFailToDelete)):
                state.failedEntryOperations.insert(.delete)
                return .none

            case .home(.delegate(.didFailToSave)):
                state.failedEntryOperations.insert(.save)
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
