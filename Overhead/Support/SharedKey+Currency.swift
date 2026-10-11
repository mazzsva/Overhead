//
//  SharedKey+Currency.swift
//  Overhead
//
//  Created by Lorenzo Mazzarotto on 11/10/26.
//

import ComposableArchitecture

extension SharedKey where Self == AppStorageKey<Currency>.Default {
    static var currency: Self {
        @Dependency(\.locale) var locale
        return Self[.appStorage("currency"), default: Currency(locale: locale)]
    }
}
