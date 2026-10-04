//
//  ExpenseDocumentTests.swift
//  OverheadTests
//
//  Created by Lorenzo Mazzarotto on 03/10/26.
//

import CustomDump
import FirebaseFirestore
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

        @Test(arguments: [
            Timestamp(seconds: 1_751_000_000, nanoseconds: 123_457_000),
            Timestamp(seconds: 1_751_000_000, nanoseconds: 999_999_000),
            Timestamp(seconds: 1_751_000_001, nanoseconds: 1000),
            Timestamp(seconds: 1_790_000_000, nanoseconds: 500_000),
            Timestamp(seconds: -1, nanoseconds: 999_999_000),
        ])
        func aStoredCreationDateRoundTripsExactly(createdAt: Timestamp) throws {
            var data = try Expense.gym.documentData()
            data["createdAt"] = createdAt

            let expense = try #require(Expense(documentID: Expense.gym.id.uuidString, data: data))

            expectNoDifference(try expense.documentData()["createdAt"] as? Timestamp, createdAt)
        }

        @Test(arguments: [-1, 0, 1_751_000_000, 2_200_000_000, 4_102_444_800])
        func everyStoredMicrosecondRoundTripsExactly(seconds: Int64) throws {
            var data = try Expense.gym.documentData()
            for microsecond in 0 ..< 1_000_000 {
                let createdAt = Timestamp(seconds: seconds, nanoseconds: Int32(microsecond) * 1000)
                data["createdAt"] = createdAt

                let expense = try #require(Expense(documentID: Expense.gym.id.uuidString, data: data))

                guard try expense.documentData()["createdAt"] as? Timestamp == createdAt else {
                    Issue.record("The creation date \(createdAt) changed after a round trip.")
                    return
                }
            }
        }

        @Test(arguments: [
            (1_751_000_000.999_999_6, Timestamp(seconds: 1_751_000_001, nanoseconds: 0)),
            (1_751_000_000.000_000_2, Timestamp(seconds: 1_751_000_000, nanoseconds: 0)),
            (1_751_000_000.123_456_7, Timestamp(seconds: 1_751_000_000, nanoseconds: 123_457_000)),
            (-0.000_000_4, Timestamp(seconds: 0, nanoseconds: 0)),
            (-0.000_000_6, Timestamp(seconds: -1, nanoseconds: 999_999_000)),
        ])
        func aNewCreationDateRoundsToTheNearestMicrosecond(interval: TimeInterval, expected: Timestamp) throws {
            let expense = Expense(
                amount: Expense.gym.amount,
                billingCycle: Expense.gym.billingCycle,
                createdAt: Date(timeIntervalSince1970: interval),
                id: Expense.gym.id,
                isActive: Expense.gym.isActive,
                name: Expense.gym.name
            )

            expectNoDifference(try expense.documentData()["createdAt"] as? Timestamp, expected)
        }

        @Test
        func aDocumentWithoutCentsIsSkipped() throws {
            var data = try Expense.gym.documentData()
            data["amountMinorUnits"] = data.removeValue(forKey: "amountInCents")

            var expense: Expense?
            withKnownIssue {
                expense = Expense(documentID: Expense.gym.id.uuidString, data: data)
            }
            expectNoDifference(expense, nil)
        }

        @Test
        func anAmountWithMoreThanTwoDecimalPlacesIsNotSaved() throws {
            var expense = Expense.gym
            expense.amount = try #require(Decimal(string: "39.901"))

            var result: Result<[String: Any], any Error> = .success([:])
            withKnownIssue {
                result = Result { try expense.documentData() }
            }
            #expect(throws: (any Error).self) {
                try result.get()
            }
        }
    }
}
