//
//  OverheadApp.swift
//  Overhead
//
//  Created by Lorenzo Mazzarotto on 04/07/26.
//

import ComposableArchitecture
import FirebaseCore
import IssueReporting
import SwiftUI

@main
struct OverheadApp: App {
    @MainActor
    static let appLockStore = Store(initialState: AppLock.State()) {
        AppLock()
    }

    @MainActor
    static let store = Store(initialState: AppFeature.State()) {
        AppFeature()
    }

    init() {
        guard !isTesting else { return }
        FirebaseApp.configure()
    }

    var body: some Scene {
        WindowGroup {
            if !isTesting {
                AppView(store: Self.store)
                    .appLock(store: Self.appLockStore, session: Self.store)
            }
        }
    }
}
