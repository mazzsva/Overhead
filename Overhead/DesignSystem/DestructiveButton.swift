//
//  DestructiveButton.swift
//  Overhead
//
//  Created by Lorenzo Mazzarotto on 12/10/26.
//

import SwiftUI

struct DestructiveButton: View {
    let title: LocalizedStringResource
    let action: () -> Void

    var body: some View {
        Button(role: .destructive, action: action) {
            Text(title)
                .foregroundStyle(Color.critical)
                .frame(maxWidth: .infinity, minHeight: 48)
                .cardBackground(.control)
        }
        .buttonStyle(.pressable(.control))
    }
}
