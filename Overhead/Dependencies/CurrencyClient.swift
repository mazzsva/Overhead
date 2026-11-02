//
//  CurrencyClient.swift
//  Overhead
//
//  Created by Lorenzo Mazzarotto on 11/10/26.
//

import AccountKit
import Dependencies
import DependenciesMacros
import Foundation
import IssueReporting
import os

typealias CurrencySnapshot = ProfileSnapshot<Currency?>

@DependencyClient
struct CurrencyClient: Sendable {
    var currency: @Sendable (_ uid: String) async -> AsyncThrowingStream<CurrencySnapshot, any Error> = { _ in
        AsyncThrowingStream { _ in }
    }

    var save: @Sendable (_ currency: Currency, _ uid: String) async throws -> Void
}

extension CurrencyClient: DependencyKey {
    static var liveValue: CurrencyClient {
        CurrencyClient(
            currency: { uid in
                await AccountStorage.shared.currency(uid: uid)
            },
            save: { currency, uid in
                try await AccountStorage.shared.saveCurrency(currency, uid: uid)
            }
        )
    }

    static var previewValue: CurrencyClient {
        CurrencyClient(
            currency: { _ in
                AsyncThrowingStream { continuation in
                    continuation.yield(.known(nil))
                }
            },
            save: { _, _ in }
        )
    }

    static var testValue: CurrencyClient {
        CurrencyClient()
    }
}

extension DependencyValues {
    var currencyClient: CurrencyClient {
        get { self[CurrencyClient.self] }
        set { self[CurrencyClient.self] = newValue }
    }
}

enum CurrencyField {
    static let currency = "currency"
}

extension Currency {
    init?(data: [String: Any]) {
        guard let value = data[CurrencyField.currency] else { return nil }
        guard let code = value as? String, let currency = Currency(rawValue: code) else {
            logger.error("Skipping a currency that failed to decode.")
            reportIssue("Skipping a currency that failed to decode.")
            return nil
        }
        self = currency
    }
}

private let logger = Logger(category: "CurrencyClient")
