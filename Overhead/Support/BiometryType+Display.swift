//
//  BiometryType+Display.swift
//  Overhead
//
//  Created by Lorenzo Mazzarotto on 30/10/26.
//

import Foundation

extension BiometryType {
    var lockTitle: LocalizedStringResource {
        switch self {
        case .faceID: "Require Face ID"
        case .opticID: "Require Optic ID"
        case .passcode: "Require Passcode"
        case .touchID: "Require Touch ID"
        }
    }

    var systemImage: String {
        switch self {
        case .faceID: "faceid"
        case .opticID: "opticid"
        case .passcode: "lock.fill"
        case .touchID: "touchid"
        }
    }
}
