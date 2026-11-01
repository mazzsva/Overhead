//
//  BiometryType.swift
//  Overhead
//
//  Created by Lorenzo Mazzarotto on 30/10/26.
//

import Foundation

enum BiometryType: Equatable, Sendable {
    case faceID
    case opticID
    case passcode
    case touchID
}
