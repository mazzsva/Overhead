//
//  AccountStorage+UserData.swift
//  Overhead
//
//  Created by Lorenzo Mazzarotto on 04/10/26.
//

import AccountKit
import FirebaseFirestore

extension AccountStorage {
    func budget(uid: String) async -> AsyncThrowingStream<BudgetSnapshot, any Error> {
        await profileSnapshots(uid: uid) { $0.flatMap(Budget.init(data:)) }
    }

    func delete(id: Expense.ID, uid: String) async throws {
        await waitForClearing()
        try await expensesCollection(uid: uid).document(id.uuidString).delete()
    }

    func deleteAllExpenses(uid: String) async throws {
        try await deleteAll(in: expensesCollectionName, uid: uid)
    }

    func currency(uid: String) async -> AsyncThrowingStream<CurrencySnapshot, any Error> {
        await profileSnapshots(uid: uid) { $0.flatMap(Currency.init(data:)) }
    }

    func deleteProfile(uid: String) async throws {
        await waitForClearing()
        try await Self.profileDocument(uid: uid).delete()
    }

    func expenses(uid: String) async -> AsyncThrowingStream<[Expense], any Error> {
        await collectionSnapshots(
            expensesCollectionName,
            uid: uid,
            subject: "Expenses",
            includeMetadataChanges: false,
            transform: { snapshot in
                snapshot.documents.compactMap { Expense(documentID: $0.documentID, data: $0.data()) }
            }
        )
    }

    func removeIncome(uid: String) async throws {
        await waitForClearing()
        try await Self.profileDocument(uid: uid)
            .updateData([
                BudgetField.income: FieldValue.delete(),
                BudgetField.investment: FieldValue.delete(),
            ])
    }

    func removeInvestment(uid: String) async throws {
        await waitForClearing()
        try await Self.profileDocument(uid: uid).updateData([BudgetField.investment: FieldValue.delete()])
    }

    func save(_ expense: Expense, uid: String) async throws {
        await waitForClearing()
        try await expensesCollection(uid: uid).document(expense.id.uuidString).setData(expense.documentData())
    }

    func saveCurrency(_ currency: Currency, uid: String) async throws {
        await waitForClearing()
        try await Self.profileDocument(uid: uid).setData([CurrencyField.currency: currency.rawValue], merge: true)
    }

    func saveIncome(_ income: Amount, removingInvestment: Bool, uid: String) async throws {
        await waitForClearing()
        var data: [String: Any] = [BudgetField.income: income.value]
        if removingInvestment {
            data[BudgetField.investment] = FieldValue.delete()
        }
        try await Self.profileDocument(uid: uid).setData(data, merge: true)
    }

    func saveInvestment(_ investment: Amount, uid: String) async throws {
        await waitForClearing()
        try await Self.profileDocument(uid: uid).setData([BudgetField.investment: investment.value], merge: true)
    }
}

private let expensesCollectionName = "expenses"

private func expensesCollection(uid: String) -> CollectionReference {
    AccountStorage.collection(expensesCollectionName, uid: uid)
}
