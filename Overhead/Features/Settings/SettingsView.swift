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

    private static var aboutText: String {
        let info = Bundle.main.infoDictionary
        let name = info?["CFBundleName"] as? String ?? "Overhead"
        let version = info?["CFBundleShortVersionString"] as? String ?? "?"
        let build = info?["CFBundleVersion"] as? String ?? "?"
        return "\(name) \(version) (\(build))"
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Label {
                        Text(store.user.email ?? String(localized: "Unknown"))
                            .lineLimit(1)
                            .truncationMode(.middle)
                    } icon: {
                        Image(systemName: "apple.logo")
                            .accessibilityLabel("Sign in with Apple")
                    }
                }
                Section {
                    Picker("Currency", selection: $store.currency.sending(\.currencyPickerChanged)) {
                        ForEach(Currency.allCases, id: \.self) { currency in
                            Text(currency.name(locale: locale))
                        }
                    }
                }
                Section {
                    Button("Sign Out", systemImage: "rectangle.portrait.and.arrow.right") {
                        store.send(.account(.signOutButtonTapped))
                    }
                }
                .listSectionSpacing(.custom(8))
                Section {
                    Button(role: .destructive) {
                        store.send(.account(.deleteAccountButtonTapped))
                    } label: {
                        Label("Delete Account", systemImage: "trash")
                            .foregroundStyle(.red)
                    }
                }
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
                ToolbarItem(placement: .primaryAction) {
                    Button("About", systemImage: "info") {
                        store.send(.infoButtonTapped)
                    }
                    .foregroundStyle(.secondary)
                    .labelStyle(.iconOnly)
                    .popover(isPresented: $store.isPresentingAbout.sending(\.aboutPresentationChanged)) {
                        Text(Self.aboutText)
                            .padding()
                            .presentationCompactAdaptation(.popover)
                    }
                }
            }
            .alert($store.scope(state: \.account.alert, action: \.account.alert))
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
