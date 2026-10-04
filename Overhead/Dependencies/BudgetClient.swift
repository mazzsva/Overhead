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
    var budget: @Sendable (_ uid: String) async -> AsyncThrowingStream<Budget?, any Error> = { _ in
        AsyncThrowingStream { _ in }
    }

    var delete: @Sendable (_ uid: String) async throws -> Void
    var save: @Sendable (_ budget: Budget, _ uid: String) async throws -> Void
}

extension BudgetClient: DependencyKey {
    static var liveValue: BudgetClient {
        BudgetClient(
            budget: { uid in
                await FirestoreStorage.shared.budget(uid: uid)
            },
            delete: { uid in
                try await FirestoreStorage.shared.deleteBudget(uid: uid)
            },
            save: { budget, uid in
                try await FirestoreStorage.shared.save(budget, uid: uid)
            }
        )
    }

    static var previewValue: BudgetClient {
        BudgetClient(
            budget: { _ in
                AsyncThrowingStream { continuation in
                    continuation.yield(.mock)
                }
            },
            delete: { _ in },
            save: { _, _ in }
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

extension Budget {
    init?(data: [String: Any]) {
        let investmentValue = data["monthlyInvestmentInCents"]
        let investmentInCents = investmentValue as? Int
        guard
            let incomeInCents = data["monthlyIncomeInCents"] as? Int,
            incomeInCents > 0,
            investmentValue == nil || (1 ... incomeInCents).contains(investmentInCents ?? 0)
        else {
            logger.error("Skipping a budget document that failed to decode.")
            reportIssue("Skipping a budget document that failed to decode.")
            return nil
        }
        self.init(
            income: Decimal(cents: incomeInCents),
            investment: investmentInCents.map(Decimal.init(cents:))
        )
    }

    func documentData() throws -> [String: Any] {
        guard let incomeInCents = income.cents else {
            reportIssue("The budget has an income that cents cannot represent.")
            throw InexactAmountError()
        }
        var data: [String: Any] = ["monthlyIncomeInCents": incomeInCents]
        if let investment {
            guard let investmentInCents = investment.cents else {
                reportIssue("The budget has an investment that cents cannot represent.")
                throw InexactAmountError()
            }
            data["monthlyInvestmentInCents"] = investmentInCents
        }
        return data
    }
}

private struct InexactAmountError: Error {}

private let logger = Logger(category: "BudgetClient")
