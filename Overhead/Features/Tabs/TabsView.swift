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
                OverviewView()
            }
            Tab("Expenses", systemImage: "list.bullet.rectangle.fill", value: .home) {
                HomeView(store: store.scope(state: \.home, action: \.home))
            }
            Tab("Settings", systemImage: "gear", value: .settings) {
                SettingsView(store: store.scope(state: \.settings, action: \.settings))
            }
        }
        .alert(
            "Something Went Wrong",
            isPresented: $store.isPresentingExpenseFailure.sending(\.expenseFailurePresentationChanged)
        ) {
        } message: {
            Text(store.expenseFailureMessage)
        }
        .task { await store.send(.home(.task)).finish() }
    }
}

#Preview {
    TabsView(
        store: Store(initialState: Tabs.State(user: .mock)) {
            Tabs()
        }
    )
}
