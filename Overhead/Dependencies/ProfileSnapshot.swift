//
//  ProfileSnapshot.swift
//  Overhead
//
//  Created by Lorenzo Mazzarotto on 11/10/26.
//

enum ProfileSnapshot<Value: Equatable & Sendable>: Equatable, Sendable {
    case known(Value)
    case unknown
}

typealias BudgetSnapshot = ProfileSnapshot<Budget?>
