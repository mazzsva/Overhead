//
//  BiometricsClient.swift
//  Overhead
//
//  Created by Lorenzo Mazzarotto on 30/10/26.
//

import Dependencies
import DependenciesMacros
import LocalAuthentication

@DependencyClient
struct BiometricsClient: Sendable {
    var authenticate: @Sendable (_ reason: String) async throws -> Bool
    var biometryType: @Sendable () -> BiometryType?
}

extension BiometricsClient: DependencyKey {
    static var liveValue: BiometricsClient {
        BiometricsClient(
            authenticate: { reason in
                do {
                    return try await LAContext().evaluatePolicy(.deviceOwnerAuthentication, localizedReason: reason)
                } catch let error as LAError where error.isCancellation {
                    return false
                }
            },
            biometryType: {
                let context = LAContext()
                guard context.canEvaluatePolicy(.deviceOwnerAuthentication, error: nil) else { return nil }
                return switch context.biometryType {
                case .faceID: .faceID
                case .opticID: .opticID
                case .touchID: .touchID
                case .none: .passcode
                @unknown default: .passcode
                }
            }
        )
    }

    static var previewValue: BiometricsClient {
        BiometricsClient(authenticate: { _ in true }, biometryType: { .faceID })
    }

    static var testValue: BiometricsClient {
        BiometricsClient()
    }
}

extension LAError {
    fileprivate var isCancellation: Bool {
        switch code {
        case .appCancel, .systemCancel, .userCancel: true
        default: false
        }
    }
}

extension DependencyValues {
    var biometricsClient: BiometricsClient {
        get { self[BiometricsClient.self] }
        set { self[BiometricsClient.self] = newValue }
    }
}
