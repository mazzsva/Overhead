//
//  HomeView.swift
//  Overhead
//
//  Created by Lorenzo Mazzarotto on 01/10/26.
//

import ComposableArchitecture
import SwiftUI

struct HomeView: View {
    @Bindable var store: StoreOf<Home>

    @Namespace private var namespace

    var body: some View {
        OverviewView(
            store: store.scope(state: \.overview, action: \.overview),
            namespace: namespace
        )
        .fullScreenCover(item: $store.screen.sending(\.screenChanged)) { screen in
            Group {
                switch screen {
                case .expenses:
                    ExpensesView(store: store.scope(state: \.expenses, action: \.expenses))
                case .settings:
                    SettingsView(store: store.scope(state: \.settings, action: \.settings))
                }
            }
            .failureAlert(isPresented: failureBinding(on: screen), message: store.failureMessage)
            .navigationTransition(.zoom(sourceID: screen, in: namespace))
        }
        .failureAlert(isPresented: failureBinding(on: nil), message: store.failureMessage)
        .task { await store.send(.expenses(.task)).finish() }
        .task { await store.send(.overview(.task)).finish() }
        .task { await store.send(.settings(.task)).finish() }
    }

    private func failureBinding(on screen: Home.Screen?) -> Binding<Bool> {
        Binding(
            get: { store.isPresentingFailure && store.screen == screen },
            set: { store.send(.failurePresentationChanged($0)) }
        )
    }
}

extension View {
    fileprivate func failureAlert(isPresented: Binding<Bool>, message: String) -> some View {
        alert("Something Went Wrong", isPresented: isPresented) {
        } message: {
            Text(message)
        }
    }
}

#Preview {
    HomeView(
        store: Store(initialState: Home.State(user: .mock)) {
            Home()
        }
    )
}
