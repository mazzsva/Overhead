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
        func aBudgetRoundTripsThroughItsDocument() throws {
            let data = try Budget.mock.documentData()

            expectNoDifference(data.keys.sorted(), ["monthlyIncomeInCents", "monthlyInvestmentInCents"])
            expectNoDifference(data["monthlyIncomeInCents"] as? Int, 300_000)
            expectNoDifference(data["monthlyInvestmentInCents"] as? Int, 45000)
            expectNoDifference(Budget(data: data), .mock)
        }

        @Test
        func aBudgetWithoutInvestmentLeavesOutTheField() throws {
            let budget = Budget(income: Decimal(cents: 250_050), investment: nil)
            let data = try budget.documentData()

            expectNoDifference(data.keys.sorted(), ["monthlyIncomeInCents"])
            expectNoDifference(Budget(data: data), budget)
        }

        @Test
        func aDocumentWithoutIncomeIsSkipped() {
            expectNoDifference(decodeReportingIssue(["monthlyInvestmentInCents": 45000]), nil)
        }

        @Test
        func aDocumentWithAnInvestmentThatIsNotCentsIsSkipped() {
            expectNoDifference(
                decodeReportingIssue(["monthlyIncomeInCents": 300_000, "monthlyInvestmentInCents": "450"]), nil)
        }

        @Test
        func aDocumentWithoutAPositiveIncomeIsSkipped() {
            expectNoDifference(decodeReportingIssue(["monthlyIncomeInCents": 0]), nil)
        }

        @Test
        func aDocumentWithoutAPositiveInvestmentIsSkipped() {
            expectNoDifference(
                decodeReportingIssue(["monthlyIncomeInCents": 300_000, "monthlyInvestmentInCents": 0]), nil)
        }

        @Test
        func aDocumentWithAnInvestmentAboveTheIncomeIsSkipped() {
            expectNoDifference(
                decodeReportingIssue(["monthlyIncomeInCents": 300_000, "monthlyInvestmentInCents": 300_001]), nil)
            expectNoDifference(
                Budget(data: ["monthlyIncomeInCents": 300_000, "monthlyInvestmentInCents": 300_000]),
                Budget(income: 3000, investment: 3000)
            )
        }

        @Test
        func anIncomeWithMoreThanTwoDecimalPlacesIsNotSaved() throws {
            let budget = Budget(income: try #require(Decimal(string: "3000.001")), investment: nil)

            #expect(throws: (any Error).self) {
                try encodeReportingIssue(budget).get()
            }
        }

        @Test
        func anInvestmentWithMoreThanTwoDecimalPlacesIsNotSaved() throws {
            let investment = try #require(Decimal(string: "450.001"))
            let budget = Budget(income: 3000, investment: investment)

            #expect(throws: (any Error).self) {
                try encodeReportingIssue(budget).get()
            }
        }

        private func decodeReportingIssue(_ data: [String: Any]) -> Budget? {
            var budget: Budget?
            withKnownIssue {
                budget = Budget(data: data)
            }
            return budget
        }

        private func encodeReportingIssue(_ budget: Budget) -> Result<[String: Any], any Error> {
            var result: Result<[String: Any], any Error> = .success([:])
            withKnownIssue {
                result = Result { try budget.documentData() }
            }
            return result
        }
    }
}
