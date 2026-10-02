//
//  SessionOrigin.swift
//  Overhead
//
//  Created by Lorenzo Mazzarotto on 02/10/26.
//

import CasePaths

@CasePathable
@dynamicMemberLookup
enum SessionOrigin: Equatable {
    case freshSignIn(isNewAccount: Bool)
    case restored
}
