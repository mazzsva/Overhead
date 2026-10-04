//
//  TabsView.swift
//  Overhead
//
//  Created by Lorenzo Mazzarotto on 01/10/26.
//

import ComposableArchitecture
import SwiftUI

struct TabsView: View {
    @Bindable var store: StoreOf<Tabs>

    var body: some View {
        TabView(selection: $store.selectedTab.sending(\.selectedTabChanged)) {
            Tab("Overview", systemImage: "square.grid.2x2", value: .overview) {
                OverviewView(store: store.scope(state: \.overview, action: \.overview))
            }
            Tab("Expenses", systemImage: "list.bullet.rectangle", value: .expenses) {
                ExpensesView(store: store.scope(state: \.expenses, action: \.expenses))
            }
            Tab("Settings", systemImage: "gear", value: .settings) {
                SettingsView(store: store.scope(state: \.settings, action: \.settings))
            }
        }
        .alert(
            "Something Went Wrong",
            isPresented: $store.isPresentingFailure.sending(\.failurePresentationChanged)
        ) {
        } message: {
            Text(store.failureMessage)
        }
        .task { await store.send(.expenses(.task)).finish() }
        .task { await store.send(.overview(.task)).finish() }
    }
}

#Preview {
    TabsView(
        store: Store(initialState: Tabs.State(user: .mock)) {
            Tabs()
        }
    )
}
