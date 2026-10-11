//
//  SharedKey+Currency.swift
//  Overhead
//
//  Created by Lorenzo Mazzarotto on 11/10/26.
//

import ComposableArchitecture

extension SharedKey where Self == InMemoryKey<Currency>.Default {
    static var currency: Self {
        @Dependency(\.locale) var locale
        return Self[.inMemory("currency"), default: Currency(locale: locale)]
    }
}
