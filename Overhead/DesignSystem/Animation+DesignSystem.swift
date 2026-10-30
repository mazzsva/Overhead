//
//  Animation+DesignSystem.swift
//  Overhead
//
//  Created by Lorenzo Mazzarotto on 12/10/26.
//

import SwiftUI

extension Animation {
    static let fade = Animation.easeInOut(duration: 0.25)
    static let glow = Animation.smooth(duration: 0.8)
    static let press = Animation.snappy(duration: 0.2)
    static let selection = Animation.snappy(duration: 0.25)
    static let step = Animation.spring(duration: 0.5, bounce: 0.12)
    static let structure = Animation.spring(duration: 0.5, bounce: 0.1).delay(0.25)
    static let typing = Animation.snappy(duration: 0.16)
    static let value = Animation.snappy(duration: 0.4)

    static func glow(reducingMotion: Bool) -> Animation {
        reducingMotion ? .fade : .glow
    }

    static func selection(reducingMotion: Bool) -> Animation {
        reducingMotion ? .fade : .selection
    }

    static func step(reducingMotion: Bool) -> Animation {
        reducingMotion ? .fade : .step
    }

    static func typing(reducingMotion: Bool) -> Animation {
        reducingMotion ? .fade : .typing
    }

    static func value(reducingMotion: Bool) -> Animation {
        reducingMotion ? .fade : .value
    }
}

extension AnyTransition {
    @MainActor
    static func replace(reducingMotion: Bool) -> AnyTransition {
        reducingMotion ? .opacity : AnyTransition(.blurReplace)
    }
}
