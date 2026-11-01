//
//  AppLockView.swift
//  Overhead
//
//  Created by Lorenzo Mazzarotto on 30/10/26.
//

import ComposableArchitecture
import SwiftUI

struct AppLockView: View {
    let store: StoreOf<AppLock>

    @Dependency(\.biometricsClient) private var biometricsClient

    var body: some View {
        VStack(spacing: 0) {
            Spacer()
            Image(systemName: "lock.fill")
                .font(.system(size: 56))
                .foregroundStyle(Color(.systemGray))
                .accessibilityHidden(true)
                .padding(.bottom, 22)
            Text("Overhead Is Locked")
                .font(.title.bold())
                .multilineTextAlignment(.center)
                .padding(.bottom, 30)
            Button {
                store.send(.unlockButtonTapped)
            } label: {
                Label("Unlock", systemImage: biometricsClient.biometryType()?.systemImage ?? "lock.open.fill")
                    .font(.headline)
                    .foregroundStyle(store.canUnlock ? Color.accentColor : Color(.tertiaryLabel))
            }
            .buttonStyle(.glass)
            .buttonBorderShape(.capsule)
            .controlSize(.large)
            .disabled(!store.canUnlock)
            Spacer()
        }
        .padding(.horizontal, 32)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .groupedBackground()
        .accessibilityElement(children: .contain)
    }
}

#Preview("Locked") {
    var state = AppLock.State()
    state.isLocked = true
    return AppLockView(
        store: Store(initialState: state) {
            AppLock()
        }
    )
}

#Preview("Covered") {
    var state = AppLock.State()
    state.isInactive = true
    state.isLocked = true
    return AppLockView(
        store: Store(initialState: state) {
            AppLock()
        }
    )
}

#Preview("Locked, Dark") {
    var state = AppLock.State()
    state.isLocked = true
    return AppLockView(
        store: Store(initialState: state) {
            AppLock()
        }
    )
    .preferredColorScheme(.dark)
}
