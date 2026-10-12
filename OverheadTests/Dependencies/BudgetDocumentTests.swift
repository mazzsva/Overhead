//
//  BudgetDocumentTests.swift
//  OverheadTests
//
//  Created by Lorenzo Mazzarotto on 04/10/26.
//

import CustomDump
import Foundation
import Testing

@testable import Overhead

extension BaseSuite {
    @Suite
    struct BudgetDocumentTests {
        @Test
        func theInvestmentIsAtMostTheIncome() {
            #expect(Budget(income: 3000, investment: 3001) == nil)
            expectNoDifference(Budget(income: 3000, investment: 3000)?.investment, 3000)
        }

        @Test
        func theMockIsAValidBudget() {
            expectNoDifference(Budget(income: 3000, investment: 450), .mock)
        }

        @Test
        func aDocumentDecodesIntoABudget() {
            expectNoDifference(
                Budget(data: [BudgetField.income: 3000, BudgetField.investment: 450]),
                .mock
            )
            expectNoDifference(
                Budget(data: [BudgetField.income: 2500]),
                Budget(income: 2500, investment: nil)
            )
        }

        @Test
        func aProfileWithoutAnIncomeHasNoBudget() {
            expectNoDifference(Budget(data: [:]), nil)
            expectNoDifference(Budget(data: [CurrencyField.currency: "EUR"]), nil)
        }

        @Test(
            arguments: [
                [BudgetField.investment: 450],
                [BudgetField.income: 0],
                [BudgetField.income: 1_000_000_000],
                [BudgetField.income: 3000.5],
                [BudgetField.income: "3000"],
                [BudgetField.income: 3000, BudgetField.investment: 0],
                [BudgetField.income: 3000, BudgetField.investment: 3001],
                [BudgetField.income: 3000, BudgetField.investment: 450.5],
                [BudgetField.income: 3000, BudgetField.investment: "450"],
            ] as [[String: any Sendable]])
        func anInvalidDocumentIsSkipped(data: [String: any Sendable]) {
            var budget: Budget? = .mock
            withKnownIssue {
                budget = Budget(data: data)
            }
            expectNoDifference(budget, nil)
        }
    }
}
