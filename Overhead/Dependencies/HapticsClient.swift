//
//  HapticsClient.swift
//  Overhead
//
//  Created by Lorenzo Mazzarotto on 15/07/26.
//

import Dependencies
import DependenciesMacros
import UIKit

@DependencyClient
struct HapticsClient: Sendable {
    var impact: @Sendable () async -> Void
    var success: @Sendable () async -> Void
    var warning: @Sendable () async -> Void
}

extension HapticsClient: DependencyKey {
    static var liveValue: HapticsClient {
        HapticsClient(
            impact: {
                await MainActor.run { UIImpactFeedbackGenerator(style: .light).impactOccurred() }
            },
            success: {
                await MainActor.run { UINotificationFeedbackGenerator().notificationOccurred(.success) }
            },
            warning: {
                await MainActor.run { UINotificationFeedbackGenerator().notificationOccurred(.warning) }
            }
        )
    }

    static var previewValue: HapticsClient {
        HapticsClient(impact: {}, success: {}, warning: {})
    }

    static var testValue: HapticsClient {
        HapticsClient()
    }
}

extension DependencyValues {
    var hapticsClient: HapticsClient {
        get { self[HapticsClient.self] }
        set { self[HapticsClient.self] = newValue }
    }
}
