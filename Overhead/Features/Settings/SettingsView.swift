//
//  SettingsView.swift
//  Overhead
//
//  Created by Lorenzo Mazzarotto on 22/07/26.
//

import ComposableArchitecture
import SwiftUI

struct SettingsView: View {
    @Bindable var store: StoreOf<Settings>

    @Environment(\.locale) private var locale

    var body: some View {
        NavigationStack {
            List {
                Section {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Email")
                        Text(store.user.email ?? String(localized: "Unknown"))
                            .foregroundStyle(.secondary)
                            .textSelection(.enabled)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .accessibilityElement(children: .combine)
                }
                Section {
                    Picker("Currency", selection: $store.currency.sending(\.currencyPickerChanged)) {
                        ForEach(Currency.allCases, id: \.self) { currency in
                            Text(currency.name(locale: locale))
                        }
                    }
                }
                .disabled(store.isDeletingAccount)
                if let biometryType = store.biometryType {
                    Section {
                        Toggle(isOn: $store.locksApp.sending(\.lockToggleChanged)) {
                            Label(String(localized: biometryType.lockTitle), systemImage: biometryType.systemImage)
                        }
                        .disabled(store.isAuthenticatingWithBiometrics)
                    } footer: {
                        Text("Overhead locks when you leave the app.")
                    }
                    .disabled(store.isDeletingAccount)
                }
                Section {
                    Button("Sign Out") {
                        store.send(.signOutButtonTapped)
                    }
                    Button("Delete Account", role: .destructive) {
                        store.send(.deleteAccountButtonTapped)
                    }
                }
                .disabled(store.isDeletingAccount)
                #if DEBUG
                Section("Developer") {
                    Button {
                        store.send(.debugAddMockExpensesButtonTapped)
                    } label: {
                        Text(verbatim: "Save Expense.mocks")
                    }
                    Button(role: .destructive) {
                        store.send(.debugDeleteAllExpensesButtonTapped)
                    } label: {
                        Text(verbatim: "Call deleteAll(uid:)")
                    }
                    Toggle(isOn: $store.showsWelcomeAtNextLaunch.sending(\.debugResetWelcomeToggleChanged)) {
                        Text(verbatim: "Reset hasDismissedWelcome")
                    }
                }
                .disabled(store.isDeletingAccount)
                #endif
            }
            .scrollBounceBehavior(.basedOnSize)
            .listSectionSpacing(.compact)
            .scrollContentBackground(.hidden)
            .groupedBackground()
            .contentMargins(.top, 8, for: .scrollContent)
            .navigationBarTitleDisplayMode(.inline)
            .toolbarRole(.editor)
            .toolbar {
                ToolbarItem(placement: .title) {
                    Text("Settings")
                        .font(.title)
                        .fontWeight(.bold)
                }
            }
            .alert($store.scope(state: \.alert, action: \.alert))
        }
        .safeAreaBar(edge: .bottom) {
            Text("Version \(Bundle.main.appVersion)")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity)
                .padding(.bottom)
        }
    }
}

extension Currency {
    fileprivate func name(locale: Locale) -> String {
        locale.localizedString(forCurrencyCode: rawValue) ?? rawValue
    }
}

#Preview {
    SettingsView(
        store: Store(initialState: Settings.State(user: .mock)) {
            Settings()
        }
    )
}
