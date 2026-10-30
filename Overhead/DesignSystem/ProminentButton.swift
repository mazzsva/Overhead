//
//  ProminentButton.swift
//  Overhead
//
//  Created by Lorenzo Mazzarotto on 30/10/26.
//

import SwiftUI

struct ProminentButton: View {
    let title: LocalizedStringResource
    let accent: Accent
    let action: () -> Void

    @Environment(\.isEnabled) private var isEnabled

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(.headline, design: .rounded))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity, minHeight: 52)
                .background(accent.fill, in: CornerRadius.control.shape)
                .opacity(isEnabled ? 1 : 0.5)
        }
        .buttonStyle(.pressable(.control))
    }
}
