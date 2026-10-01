//
//  HomeView.swift
//  Overhead
//
//  Created by Lorenzo Mazzarotto on 24/07/26.
//

import ComposableArchitecture
import SwiftUI

struct HomeView: View {
    @Bindable var store: StoreOf<Home>

    var body: some View {
        let visibleEntries = store.filteredEntries
        NavigationStack(path: $store.scope(state: \.path, action: \.path)) {
            ScrollView {
                LazyVStack(spacing: 16) {
                    ForEach(visibleEntries) { $entry in
                        NavigationLink(state: EntryDetail.State(entry: $entry)) {
                            EntryCardView(entry: entry)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
            }
            .scrollIndicators(.hidden)
            .groupedBackground()
            .navigationBarTitleDisplayMode(.inline)
            .toolbarRole(.editor)
            .toolbar {
                ToolbarItem(placement: .title) {
                    VStack(alignment: .leading, spacing: 0) {
                        Text("Overhead")
                            .font(.title)
                            .fontWeight(.bold)
                        SyncStatusLabel(entryCount: store.entryCount, status: store.syncStatus)
                    }
                }
                if store.canFilterBookmarks {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button(
                            store.isShowingBookmarkedOnly ? "Show All Entries" : "Show Bookmarked Entries",
                            systemImage: store.isShowingBookmarkedOnly ? "bookmark.fill" : "bookmark"
                        ) {
                            store.send(.bookmarkFilterButtonTapped)
                        }
                        .labelStyle(.iconOnly)
                        .tint(store.isShowingBookmarkedOnly ? .bookmark : .secondary)
                    }
                    ToolbarSpacer(.fixed, placement: .topBarTrailing)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("New Entry", systemImage: "plus") {
                        store.send(.newEntryButtonTapped)
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
            .overlay {
                switch store.emptyState {
                case .bookmarks:
                    ContentUnavailableView(
                        "No Bookmarks",
                        systemImage: "bookmark.fill",
                        description: Text("Bookmark an entry to find it here.")
                    )
                case .entries:
                    ContentUnavailableView(
                        "No Entries",
                        systemImage: "tray.fill",
                        description: Text("Tap the plus button to add an entry.")
                    )
                case nil:
                    EmptyView()
                }
            }
        } destination: { detailStore in
            EntryDetailView(store: detailStore)
        }
        .alert($store.scope(state: \.destination?.alert, action: \.destination.alert))
        .sheet(
            item: $store.scope(state: \.destination?.createEntry, action: \.destination.createEntry)
        ) { formStore in
            EntryFormView(store: formStore)
        }
    }
}

#Preview("Populated") {
    let store = Store(initialState: Home.State(user: .mock)) {
        Home()
    }
    HomeView(store: store)
        .task { await store.send(.task).finish() }
}

#Preview("Empty") {
    let store = Store(initialState: Home.State(user: .mock)) {
        Home()
    } withDependencies: {
        $0.entriesClient.entries = { _ in
            AsyncThrowingStream { continuation in
                continuation.yield(.empty)
            }
        }
    }
    HomeView(store: store)
        .task { await store.send(.task).finish() }
}

#Preview("Syncing") {
    let store = Store(initialState: Home.State(user: .mock)) {
        Home()
    } withDependencies: {
        $0.entriesClient.entries = { _ in
            AsyncThrowingStream { continuation in
                continuation.yield(.syncing)
            }
        }
    }
    HomeView(store: store)
        .task { await store.send(.task).finish() }
}

#Preview("Offline") {
    let store = Store(initialState: Home.State(user: .mock)) {
        Home()
    } withDependencies: {
        $0.networkMonitorClient.connectivityChanges = {
            AsyncStream { continuation in
                continuation.yield(false)
            }
        }
    }
    HomeView(store: store)
        .task { await store.send(.task).finish() }
}
