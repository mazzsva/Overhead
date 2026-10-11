//
//  BudgetClient.swift
//  Overhead
//
//  Created by Lorenzo Mazzarotto on 04/10/26.
//

import Dependencies
import DependenciesMacros
import Foundation
import IssueReporting
import os

@DependencyClient
struct BudgetClient: Sendable {
    var budget: @Sendable (_ uid: String) async -> AsyncThrowingStream<BudgetSnapshot, any Error> = { _ in
        AsyncThrowingStream { _ in }
    }

    var delete: @Sendable (_ uid: String) async throws -> Void
    var removeInvestment: @Sendable (_ uid: String) async throws -> Void
    var saveIncome: @Sendable (_ income: Decimal, _ removingInvestment: Bool, _ uid: String) async throws -> Void
    var saveInvestment: @Sendable (_ investment: Decimal, _ uid: String) async throws -> Void
}

extension BudgetClient: DependencyKey {
    static var liveValue: BudgetClient {
        BudgetClient(
            budget: { uid in
                await FirestoreStorage.shared.budget(uid: uid)
            },
            delete: { uid in
                try await FirestoreStorage.shared.deleteProfile(uid: uid)
            },
            removeInvestment: { uid in
                try await FirestoreStorage.shared.removeInvestment(uid: uid)
            },
            saveIncome: { income, removingInvestment, uid in
                try await FirestoreStorage.shared.saveIncome(income, removingInvestment: removingInvestment, uid: uid)
            },
            saveInvestment: { investment, uid in
                try await FirestoreStorage.shared.saveInvestment(investment, uid: uid)
            }
        )
    }

    static var previewValue: BudgetClient {
        BudgetClient(
            budget: { _ in
                AsyncThrowingStream { continuation in
                    continuation.yield(.known(.mock))
                }
            },
            delete: { _ in },
            removeInvestment: { _ in },
            saveIncome: { _, _, _ in },
            saveInvestment: { _, _ in }
        )
    }

    static var testValue: BudgetClient {
        BudgetClient()
    }
}

extension DependencyValues {
    var budgetClient: BudgetClient {
        get { self[BudgetClient.self] }
        set { self[BudgetClient.self] = newValue }
    }
}

enum BudgetField {
    static let income = "monthlyIncomeInCents"
    static let investment = "monthlyInvestmentInCents"

    static func cents(of amount: Decimal) throws -> Int {
        guard let cents = amount.cents else {
            reportIssue("The budget has an amount that cents cannot represent.")
            throw InexactAmountError()
        }
        return cents
    }
}

extension Budget {
    init?(data: [String: Any]) {
        let investmentValue = data[BudgetField.investment]
        let investmentInCents = investmentValue as? Int
        guard
            let incomeInCents = data[BudgetField.income] as? Int,
            investmentValue == nil || investmentInCents != nil,
            let budget = Budget(
                income: Decimal(cents: incomeInCents),
                investment: investmentInCents.map(Decimal.init(cents:))
            )
        else {
            logger.error("Skipping a budget document that failed to decode.")
            reportIssue("Skipping a budget document that failed to decode.")
            return nil
        }
        self = budget
    }
}

private struct InexactAmountError: Error {}

private let logger = Logger(category: "BudgetClient")
