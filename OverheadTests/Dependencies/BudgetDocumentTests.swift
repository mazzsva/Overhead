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
        func aBudgetNeedsAPositiveIncomeInCents() throws {
            #expect(Budget(income: 0, investment: nil) == nil)
            #expect(Budget(income: -1, investment: nil) == nil)
            #expect(Budget(income: try #require(Decimal(string: "3000.001")), investment: nil) == nil)
            expectNoDifference(Budget(income: Decimal(cents: 1), investment: nil)?.income, Decimal(cents: 1))
        }

        @Test
        func theInvestmentIsAboveZeroAndAtMostTheIncome() throws {
            let investment = try #require(Decimal(string: "450.001"))
            #expect(Budget(income: 3000, investment: 0) == nil)
            #expect(Budget(income: 3000, investment: -1) == nil)
            #expect(Budget(income: 3000, investment: Decimal(cents: 300_001)) == nil)
            #expect(Budget(income: 3000, investment: investment) == nil)
            expectNoDifference(Budget(income: 3000, investment: 3000)?.investment, 3000)
        }

        @Test
        func theMockIsAValidBudget() {
            expectNoDifference(Budget(income: 3000, investment: 450), .mock)
        }

        @Test
        func aDocumentDecodesIntoABudget() {
            expectNoDifference(
                Budget(data: [BudgetField.income: 300_000, BudgetField.investment: 45000]),
                .mock
            )
            expectNoDifference(
                Budget(data: [BudgetField.income: 250_050]),
                Budget(income: Decimal(cents: 250_050), investment: nil)
            )
        }

        @Test(
            arguments: [
                [BudgetField.investment: 45000],
                [BudgetField.income: 0],
                [BudgetField.income: "300000"],
                [BudgetField.income: 300_000, BudgetField.investment: 0],
                [BudgetField.income: 300_000, BudgetField.investment: 300_001],
                [BudgetField.income: 300_000, BudgetField.investment: "450"],
            ] as [[String: any Sendable]])
        func anInvalidDocumentIsSkipped(data: [String: any Sendable]) {
            var budget: Budget? = .mock
            withKnownIssue {
                budget = Budget(data: data)
            }
            expectNoDifference(budget, nil)
        }

        @Test
        func anAmountWithMoreThanTwoDecimalPlacesHasNoStoredCents() throws {
            let amount = try #require(Decimal(string: "450.001"))

            var result: Result<Int, any Error> = .success(0)
            withKnownIssue {
                result = Result { try BudgetField.cents(of: amount) }
            }
            #expect(throws: (any Error).self) {
                try result.get()
            }
            expectNoDifference(try BudgetField.cents(of: 450), 45000)
        }
    }
}
