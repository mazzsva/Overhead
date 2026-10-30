//
//  CornerRadius.swift
//  Overhead
//
//  Created by Lorenzo Mazzarotto on 12/10/26.
//

import SwiftUI

enum CornerRadius: CGFloat {
    case control = 18
    case hero = 28
    case tile = 22

    var shape: RoundedRectangle {
        RoundedRectangle(cornerRadius: rawValue, style: .continuous)
    }
}

extension View {
    func cardBackground(_ radius: CornerRadius) -> some View {
        background(Color(.secondarySystemGroupedBackground), in: radius.shape)
    }
}
