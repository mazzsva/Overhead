//
//  ConfirmationDialogState+DiscardChanges.swift
//  Overhead
//
//  Created by Lorenzo Mazzarotto on 05/10/26.
//

import ComposableArchitecture
import Foundation

extension ConfirmationDialogState {
    static func discardChanges(_ action: Action) -> Self {
        ConfirmationDialogState(titleVisibility: .hidden) {
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
