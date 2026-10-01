//
//  Tabs.swift
//  Overhead
//
//  Created by Lorenzo Mazzarotto on 01/10/26.
//

import ComposableArchitecture

@Reducer
struct Tabs {
    enum Tab: Hashable {
        case home
        case settings
    }

    @ObservableState
    struct State: Equatable {
        var home: Home.State
        var selectedTab = Tab.home
        var settings: Settings.State
        let user: User

        init(user: User, sessionOrigin: Home.State.SessionOrigin = .restored) {
            home = Home.State(user: user, sessionOrigin: sessionOrigin)
            settings = Settings.State(user: user)
            self.user = user
        }
    }

    enum Action {
        case home(Home.Action)
        case selectedTabChanged(Tab)
        case settings(Settings.Action)
        case task
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
            case .home, .settings:
                return .none

            case .selectedTabChanged(let tab):
                state.selectedTab = tab
                return .none

            case .task:
                return .send(.home(.task))
            }
        }
    }
}
