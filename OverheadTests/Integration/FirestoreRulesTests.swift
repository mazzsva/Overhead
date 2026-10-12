//
//  FirestoreRulesTests.swift
//  OverheadTests
//
//  Created by Lorenzo Mazzarotto on 04/10/26.
//

import FirebaseFirestore
import Foundation
import Testing

@testable import Overhead

extension BaseSuite.IntegrationSuite {
    @Suite
    struct FirestoreRulesTests {
        @Test
        func theOwnerCanWriteAValidProfile() async throws {
            let uid = try await FirebaseEmulators.signIn()

            try await profile(uid).setData(["monthlyIncome": 3000])
            try await profile(uid).setData(["monthlyIncome": 3000, "monthlyInvestment": 3000])
            try await profile(uid).setData(["currency": "EUR"])
            try await profile(uid).setData(["currency": "BRL", "monthlyIncome": 3000])
            try await profile(uid).setData([:])
            try await profile(uid).delete()
        }

        @Test(
            arguments: [
                ["monthlyIncome": 0],
                ["monthlyIncome": -1],
                ["monthlyIncome": 1.5],
                ["monthlyIncome": 1_000_000_000],
                ["monthlyIncome": "3000"],
                ["monthlyIncome": 3000, "monthlyInvestment": 0],
                ["monthlyIncome": 3000, "monthlyInvestment": 3001],
                ["monthlyIncome": 3000, "monthlyInvestment": true],
                ["monthlyIncome": 3000, "defaultCurrency": "USD"],
                ["monthlyInvestment": 450],
                ["currency": "GBP"],
                ["currency": "usd"],
                ["currency": 1],
            ] as [[String: any Sendable]])
        func theRulesRefuseAnInvalidProfile(data: [String: any Sendable]) async throws {
            let uid = try await FirebaseEmulators.signIn()

            await expectRefused {
                try await profile(uid).setData(data)
            }
        }

        @Test(
            arguments: [
                ["monthlyIncome": 0],
                ["monthlyIncome": 3000, "monthlyInvestment": 3001],
                ["monthlyIncome": 3000, "defaultCurrency": "USD"],
            ] as [[String: any Sendable]])
        func theRulesRefuseReplacingABudgetWithAnInvalidOne(data: [String: any Sendable]) async throws {
            let uid = try await FirebaseEmulators.signIn()
            try await profile(uid).setData(["monthlyIncome": 3000, "monthlyInvestment": 450])

            await expectRefused {
                try await profile(uid).setData(data)
            }
        }

        @Test
        func theRulesRefuseAnUpdateThatLeavesAnInvalidBudget() async throws {
            let uid = try await FirebaseEmulators.signIn()
            try await profile(uid).setData(["monthlyIncome": 3000, "monthlyInvestment": 450])

            await expectRefused {
                try await profile(uid).updateData(["monthlyInvestment": 3001])
            }
            await expectRefused {
                try await profile(uid).updateData(["monthlyIncome": FieldValue.delete()])
            }
            await expectRefused {
                try await profile(uid).updateData(["monthlyIncome": 400])
            }
            await expectRefused {
                try await profile(uid).setData(["defaultCurrency": "USD"], merge: true)
            }
        }

        @Test
        func theOwnerCanWriteAValidExpense() async throws {
            let uid = try await FirebaseEmulators.signIn()
            let document = expense(uid, Expense.gym.id)

            try await document.setData(Expense.gym.documentData())
            var data = Expense.gym.documentData()
            data["isActive"] = false
            data["name"] = String(repeating: "a", count: Expense.maximumNameLength)
            try await document.setData(data)
            try await document.delete()
        }

        @Test(
            arguments: [
                ("amount", 0),
                ("amount", -1),
                ("amount", 39.9),
                ("amount", 1_000_000_000),
                ("billingCycle", "weekly"),
                ("createdAt", "2026-10-04"),
                ("isActive", "yes"),
                ("name", ""),
                ("name", String(repeating: "a", count: Expense.maximumNameLength + 1)),
                ("currency", "USD"),
            ] as [(String, any Sendable)])
        func theRulesRefuseAnInvalidExpense(field: String, value: any Sendable) async throws {
            let uid = try await FirebaseEmulators.signIn()
            var data = Expense.gym.documentData()
            data[field] = value

            await expectRefused {
                try await expense(uid, Expense.gym.id).setData(data)
            }
        }

        @Test(
            arguments: [
                ("amount", 0),
                ("billingCycle", "weekly"),
                ("isActive", "yes"),
                ("name", ""),
                ("currency", "USD"),
            ] as [(String, any Sendable)])
        func theRulesRefuseAnInvalidExpenseUpdate(field: String, value: any Sendable) async throws {
            let uid = try await FirebaseEmulators.signIn()
            let document = expense(uid, Expense.gym.id)
            try await document.setData(Expense.gym.documentData())
            var data = Expense.gym.documentData()
            data[field] = value

            await expectRefused {
                try await document.setData(data)
            }
            await expectRefused {
                try await document.updateData([field: value])
            }
        }

        @Test(arguments: [
            String(repeating: "a", count: Expense.maximumNameLength),
            String(repeating: "é", count: Expense.maximumNameLength),
            String(repeating: "👍🏽", count: Expense.maximumNameLength / 4),
            String(repeating: "家", count: Expense.maximumNameLength),
        ])
        func theRulesAcceptEveryNameTheAppAccepts(name: String) async throws {
            let uid = try await FirebaseEmulators.signIn()
            var data = Expense.gym.documentData()
            data["name"] = name

            try await expense(uid, Expense.gym.id).setData(data)
        }

        @Test(arguments: [
            String(repeating: "é", count: Expense.maximumNameLength + 1),
            String(repeating: "👍🏽", count: Expense.maximumNameLength / 4 + 1),
        ])
        func theRulesRefuseEveryNameTheAppRefuses(name: String) async throws {
            let uid = try await FirebaseEmulators.signIn()
            var data = Expense.gym.documentData()
            data["name"] = name

            await expectRefused {
                try await expense(uid, Expense.gym.id).setData(data)
            }
        }

        @Test(arguments: ["amount", "billingCycle", "createdAt", "isActive", "name"])
        func theRulesRefuseAnExpenseWithoutAField(field: String) async throws {
            let uid = try await FirebaseEmulators.signIn()
            var data = Expense.gym.documentData()
            data[field] = nil

            await expectRefused {
                try await expense(uid, Expense.gym.id).setData(data)
            }
        }

        @Test
        func theRulesKeepTheCreationDate() async throws {
            let uid = try await FirebaseEmulators.signIn()
            let document = expense(uid, Expense.gym.id)
            try await document.setData(Expense.gym.documentData())
            var data = Expense.gym.documentData()
            data["createdAt"] = Timestamp(date: Date(timeIntervalSince1970: 0))

            await expectRefused {
                try await document.setData(data)
            }
        }

        @Test
        func theRulesRefuseAnotherUsersData() async throws {
            let owner = try await FirebaseEmulators.signIn()
            try await profile(owner).setData(["monthlyIncome": 3000])
            try await expense(owner, Expense.gym.id).setData(Expense.gym.documentData())
            _ = try await FirebaseEmulators.signIn()

            await expectRefused {
                _ = try await profile(owner).getDocument(source: .server)
            }
            await expectRefused {
                _ = try await expense(owner, Expense.gym.id).getDocument(source: .server)
            }
            await expectRefused {
                try await expense(owner, Expense.gym.id).delete()
            }
            await expectRefused {
                try await profile(owner).delete()
            }
            await expectRefused {
                try await profile(owner).setData(["monthlyIncome": 1])
            }
            await expectRefused {
                try await expense(owner, Expense.gym.id).setData(Expense.gym.documentData())
            }
            await expectRefused {
                try await expense(owner, Expense.rent.id).setData(Expense.rent.documentData())
            }
            await expectRefused {
                _ = try await profile(owner).collection("expenses").getDocuments(source: .server)
            }
        }

        @Test
        func theRulesRefuseASignedOutUser() async throws {
            let owner = try await FirebaseEmulators.signIn()
            try await profile(owner).setData(["monthlyIncome": 3000])
            try await expense(owner, Expense.gym.id).setData(Expense.gym.documentData())
            try FirebaseEmulators.signOut()

            await expectRefused {
                _ = try await profile(owner).getDocument(source: .server)
            }
            await expectRefused {
                _ = try await profile(owner).collection("expenses").getDocuments(source: .server)
            }
            await expectRefused {
                try await profile(owner).setData(["monthlyIncome": 1])
            }
        }

        private func expectRefused(
            sourceLocation: SourceLocation = #_sourceLocation,
            _ operation: () async throws -> Void
        ) async {
            do {
                try await operation()
                Issue.record("The rules accepted the operation.", sourceLocation: sourceLocation)
            } catch {
                let error = error as NSError
                #expect(
                    error.domain == FirestoreErrorDomain && error.code == FirestoreErrorCode.permissionDenied.rawValue,
                    "Expected a permission error, got \(error).",
                    sourceLocation: sourceLocation
                )
            }
        }

        private func expense(_ uid: String, _ id: Expense.ID) -> DocumentReference {
            profile(uid).collection("expenses").document(id.uuidString)
        }

        private func profile(_ uid: String) -> DocumentReference {
            Firestore.firestore().collection("users").document(uid)
        }
    }
}
