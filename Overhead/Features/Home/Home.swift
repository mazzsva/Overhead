//
//  Home.swift
//  Overhead
//
//  Created by Lorenzo Mazzarotto on 01/10/26.
//

import AccountKit
import ComposableArchitecture
import Foundation

@Reducer
struct Home {
    enum FailedOperation: Hashable {
        case budget(Overview.BudgetChange)
        case deleteExpense
        case saveCurrency
        case saveExpense
    }

    enum Screen: Hashable, Identifiable {
        case expenses
        case settings

        var id: Self { self }
    }

    @ObservableState
    struct State: Equatable {
        @Presents var accountDeletion: AccountDeletion.State?
        var expenses: Expenses.State
        var failedOperations: Set<FailedOperation> = []
        @SharedReader(.hasDismissedWelcome) var hasDismissedWelcome
        var overview: Overview.State
        var screen: Screen?
        var settings: Settings.State
        let user: AccountUser

        init(user: AccountUser, sessionOrigin: SessionOrigin = .restored) {
            let expenses = Expenses.State(user: user, sessionOrigin: sessionOrigin)
            self.expenses = expenses
            overview = Overview.State(expenses: SharedReader(expenses.$expenses), user: user)
            settings = Settings.State(user: user)
            self.user = user
        }

        var failureMessage: String {
            switch failedOperations {
            case [.budget(.removeIncome)]:
                return String(localized: "Your income couldn't be removed.")
            case [.budget(.removeInvestments)]:
                return String(localized: "Your savings couldn't be removed.")
            case [.budget(.saveIncome)]:
                return String(localized: "Your income couldn't be saved.")
            case [.budget(.saveInvestments)]:
                return String(localized: "Your savings couldn't be updated.")
            case [.deleteExpense]:
                return String(localized: "Your expense couldn't be deleted.")
            case [.saveCurrency]:
                return String(localized: "Your currency couldn't be saved.")
            case [.saveExpense]:
                return String(localized: "Your expense couldn't be saved.")
            default:
                return String(localized: "Some of your changes couldn't be saved.")
            }
        }

        var isDeletingAccount: Bool { accountDeletion != nil }

        var isLoadingFirstContent: Bool { expenses.isLoadingFirstExpenses }

        var isPresentingFailure: Bool {
            !failedOperations.isEmpty && !isPresentingAnythingElse
        }

        var isReauthenticating: Bool { accountDeletion?.step == .reauthenticating }

        var sessionOrigin: SessionOrigin { expenses.sessionOrigin }

        subscript(isPresentingFailureOn screen: Screen?) -> Bool {
            isPresentingFailure && self.screen == screen
        }

        private var isPresentingAnythingElse: Bool {
            accountDeletion != nil || expenses.isPresenting || overview.isPresenting || settings.isPresenting
                || isLoadingFirstContent || !hasDismissedWelcome
        }
    }

    enum Action {
        case accountDeletion(PresentationAction<AccountDeletion.Action>)
        case expenses(Expenses.Action)
        case failurePresentationChanged(Bool)
        case overview(Overview.Action)
        case screenChanged(Home.Screen?)
        case settings(Settings.Action)
    }

    var body: some Reducer<State, Action> {
        Scope(state: \.expenses, action: \.expenses) {
            Expenses()
        }
        Scope(state: \.overview, action: \.overview) {
            Overview()
        }
        Scope(state: \.settings, action: \.settings) {
            Settings()
        }
        Reduce { state, action in
            switch action {
            case .accountDeletion(.presented(.delegate(.didCancel))):
                state.accountDeletion = nil
                state.screen = .settings
                return .none

            case .accountDeletion(.presented(.delegate(.didFail(let failure)))):
                state.accountDeletion = nil
                state.settings.account.alert = .accountDeletionFailed(failure)
                state.screen = .settings
                return .none

            case .accountDeletion:
                return .none

            case .expenses(.delegate(.didFailToDelete)):
                state.failedOperations.insert(.deleteExpense)
                return .none

            case .expenses(.delegate(.didFailToSave)):
                state.failedOperations.insert(.saveExpense)
                return .none

            case .failurePresentationChanged(false):
                guard state.isPresentingFailure else { return .none }
                state.failedOperations.removeAll()
                return .none

            case .failurePresentationChanged(true):
                return .none

            case .overview(.delegate(.didFailToChangeBudget(let change))):
                state.failedOperations.insert(.budget(change))
                return .none

            case .overview(.delegate(.didSelectExpenses)):
                state.screen = .expenses
                return .none

            case .overview(.delegate(.didSelectSettings)):
                state.screen = .settings
                return .none

            case .screenChanged(let screen):
                state.screen = screen
                return .none

            case .settings(.delegate(.didFailToSaveCurrency)):
                state.failedOperations.insert(.saveCurrency)
                return .none

            case .settings(.account(.delegate(.didConfirmAccountDeletion))):
                state.screen = nil
                state.accountDeletion = AccountDeletion.State(uid: state.user.uid)
                return .send(.accountDeletion(.presented(.deletionConfirmed)))

            case .settings:
                if state.settings.account.alert != nil {
                    state.screen = .settings
                }
                return .none

            case .expenses, .overview:
                return .none
            }
        }
        .ifLet(\.$accountDeletion, action: \.accountDeletion) {
            AccountDeletion()
        }
    }
}

extension Home: SignedInFeature {
    static func clearLocalData() async throws {
        @Dependency(\.expensesClient) var expensesClient
        try await expensesClient.clearLocalData()
    }

    static func deleteUserData(uid: String, didDeleteSomeData: @Sendable () async -> Void) async throws {
        try await FirestoreStorage.shared.deleteProfile(uid: uid)
        await didDeleteSomeData()
        try await FirestoreStorage.shared.deleteAll(uid: uid)
    }
}

extension Home.State: SignedInState {}
