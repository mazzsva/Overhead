//
//  SettingsView.swift
//  Overhead
//
//  Created by Lorenzo Mazzarotto on 22/07/26.
//

import AccountKit
import ComposableArchitecture
import SwiftUI

struct SettingsView: View {
    @Bindable var store: StoreOf<Settings>

    @Environment(\.dismiss) private var dismiss
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
                } footer: {
                    Text("Using Sign in with Apple")
                }
                Section {
                    Picker("Currency", selection: $store.currency.sending(\.currencyPickerChanged)) {
                        ForEach(Currency.allCases, id: \.self) { currency in
                            Text(currency.name(locale: locale))
                        }
                    }
                }
                Section {
                    Button("Sign Out") {
                        store.send(.signOutButtonTapped)
                    }
                }
                .listSectionSpacing(.custom(8))
                Section {
                    Button("Delete Account", role: .destructive) {
                        store.send(.deleteAccountButtonTapped)
                    }
                }
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
                #endif
            }
            .navigationBarBackButtonHidden()
            .scrollBounceBehavior(.basedOnSize)
            .listSectionSpacing(.compact)
            .scrollContentBackground(.hidden)
            .groupedBackground()
            .navigationTitle("Settings")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Dismiss", systemImage: "xmark") {
                        dismiss()
                    }
                    .foregroundStyle(.secondary)
                    .labelStyle(.iconOnly)
                }
            }
            .alert($store.scope(state: \.destination?.alert, action: \.destination.alert))
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
