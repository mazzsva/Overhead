//
//  SharedKey+HidesAmounts.swift
//  Overhead
//
//  Created by Lorenzo Mazzarotto on 11/10/26.
//

import ComposableArchitecture

extension SharedKey where Self == AppStorageKey<Bool>.Default {
    static var hidesAmounts: Self {
        Self[.appStorage("hidesAmounts"), default: false]
    }
}
