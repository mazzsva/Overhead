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
            withKnownIssue {
                expectNoDifference(Budget(data: ["monthlyInvestmentInCents": 45000]), nil)
            }
        }

        @Test
        func aDocumentWithAnInvestmentThatIsNotCentsIsSkipped() {
            withKnownIssue {
                expectNoDifference(
                    Budget(data: ["monthlyIncomeInCents": 300_000, "monthlyInvestmentInCents": "450"]),
                    nil
                )
            }
        }

        @Test
        func aDocumentWithoutAPositiveIncomeIsSkipped() {
            withKnownIssue {
                expectNoDifference(Budget(data: ["monthlyIncomeInCents": 0]), nil)
            }
        }

        @Test
        func aDocumentWithoutAPositiveInvestmentIsSkipped() {
            withKnownIssue {
                expectNoDifference(
                    Budget(data: ["monthlyIncomeInCents": 300_000, "monthlyInvestmentInCents": 0]),
                    nil
                )
            }
        }

        @Test
        func aDocumentWithAnInvestmentAboveTheIncomeIsSkipped() {
            withKnownIssue {
                expectNoDifference(
                    Budget(data: ["monthlyIncomeInCents": 300_000, "monthlyInvestmentInCents": 300_001]),
                    nil
                )
            }
            expectNoDifference(
                Budget(data: ["monthlyIncomeInCents": 300_000, "monthlyInvestmentInCents": 300_000]),
                Budget(income: 3000, investment: 3000)
            )
        }

        @Test
        func anIncomeWithMoreThanTwoDecimalPlacesIsNotSaved() throws {
            let budget = Budget(income: try #require(Decimal(string: "3000.001")), investment: nil)

            withKnownIssue {
                #expect(throws: (any Error).self) {
                    try budget.documentData()
                }
            }
        }

        @Test
        func anInvestmentWithMoreThanTwoDecimalPlacesIsNotSaved() throws {
            let investment = try #require(Decimal(string: "450.001"))
            let budget = Budget(income: 3000, investment: investment)

            withKnownIssue {
                #expect(throws: (any Error).self) {
                    try budget.documentData()
                }
            }
        }
    }
}
