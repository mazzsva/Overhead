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
            .failureAlert(
                isPresented: $store[isPresentingFailureOn: screen].sending(\.failurePresentationChanged),
                message: store.failureMessage
            )
            .navigationTransition(.zoom(sourceID: screen, in: namespace))
        }
        .failureAlert(
            isPresented: $store[isPresentingFailureOn: nil].sending(\.failurePresentationChanged),
            message: store.failureMessage
        )
        .task { await store.send(.expenses(.task)).finish() }
        .task { await store.send(.overview(.task)).finish() }
        .task { await store.send(.settings(.task)).finish() }
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
