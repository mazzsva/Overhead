//
//  SharedKey+DefaultCurrency.swift
//  Overhead
//
//  Created by Lorenzo Mazzarotto on 03/10/26.
//

import ComposableArchitecture

extension SharedKey where Self == InMemoryKey<String?> {
    static func defaultCurrencyCode(uid: String) -> Self {
        .inMemory("defaultCurrencyCode/\(uid)")
    }
}
