//
//  AlertState+DiscardChanges.swift
//  Overhead
//
//  Created by Lorenzo Mazzarotto on 04/10/26.
//

import ComposableArchitecture
import Foundation

extension AlertState {
    static func discardChanges(_ action: Action) -> Self {
        AlertState {
            TextState("Discard Changes?")
        } actions: {
            ButtonState(role: .destructive, action: action) {
                TextState("Discard Changes")
            }
            ButtonState(role: .cancel) {
                TextState("Keep Editing")
            }
        }
    }
}
