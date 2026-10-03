//
//  ExpenseDocumentTests.swift
//  OverheadTests
//
//  Created by Lorenzo Mazzarotto on 03/10/26.
//

import CustomDump
import Foundation
import Testing

@testable import Overhead

extension BaseSuite {
    @Suite
    struct ExpenseDocumentTests {
        @Test
        func anExpenseRoundTripsThroughItsDocument() throws {
            let data = try Expense.gym.documentData()

            expectNoDifference(data.keys.sorted(), ["amountInCents", "billingCycle", "createdAt", "isActive", "name"])
            expectNoDifference(data["amountInCents"] as? Int, 3990)
            expectNoDifference(Expense(documentID: Expense.gym.id.uuidString, data: data), .gym)
        }

        @Test
        func aDocumentWithoutCentsIsSkipped() throws {
            var data = try Expense.gym.documentData()
            data["amountMinorUnits"] = data.removeValue(forKey: "amountInCents")

            withKnownIssue {
                expectNoDifference(Expense(documentID: Expense.gym.id.uuidString, data: data), nil)
            }
        }

        @Test
        func anAmountWithMoreThanTwoDecimalPlacesIsNotSaved() throws {
            var expense = Expense.gym
            expense.amount = try #require(Decimal(string: "39.901"))

            withKnownIssue {
                #expect(throws: (any Error).self) {
                    try expense.documentData()
                }
            }
        }
    }
}
