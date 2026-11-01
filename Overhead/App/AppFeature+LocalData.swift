//
//  AppFeature+LocalData.swift
//  Overhead
//
//  Created by Lorenzo Mazzarotto on 31/10/26.
//

import ComposableArchitecture

extension AppFeature {
    func clearAppLocalData() async throws {
        @Dependency(\.expensesClient) var expensesClient
        try await expensesClient.clearLocalData()
    }
}
