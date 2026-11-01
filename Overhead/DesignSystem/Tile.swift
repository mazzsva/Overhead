//
//  Tile.swift
//  Overhead
//
//  Created by Lorenzo Mazzarotto on 12/10/26.
//

import SwiftUI

struct Tile<Value: View, Caption: View>: View {
    let title: LocalizedStringResource
    let accent: Accent
    @ViewBuilder let value: Value
    @ViewBuilder let caption: Caption

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Marker(color: accent.color)
                Text(title)
                    .fontWeight(.semibold)
                    .foregroundStyle(.secondary)
                    .contentTransition(.interpolate)
            }
            .font(.subheadline)
            .unredacted()
            VStack(alignment: .leading, spacing: 2) {
                value
                    .font(.system(.title2, design: .rounded, weight: .semibold))
                caption
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 4)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .cardBackground(.tile)
        .accessibilityElement(children: .combine)
    }
}

struct Marker: View {
    let color: Color

    @ScaledMetric private var size = 10

    var body: some View {
        RoundedRectangle(cornerRadius: size * 0.3, style: .continuous)
            .fill(color)
            .frame(width: size, height: size)
            .animation(.fade, value: color)
    }
}
