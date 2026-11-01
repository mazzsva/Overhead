//
//  SharedKey+LocksApp.swift
//  Overhead
//
//  Created by Lorenzo Mazzarotto on 30/10/26.
//

import ComposableArchitecture

extension SharedKey where Self == AppStorageKey<Bool>.Default {
    static var locksApp: Self {
        Self[.appStorage("locksApp"), default: false]
    }
}

extension SharedKey where Self == InMemoryKey<Bool>.Default {
    static var isAuthenticatingWithBiometrics: Self {
        Self[.inMemory("isAuthenticatingWithBiometrics"), default: false]
    }
}
