//
//  Accent.swift
//  Overhead
//
//  Created by Lorenzo Mazzarotto on 12/10/26.
//

import SwiftUI

enum Accent: Equatable {
    case available
    case expenses
    case income
    case neutral
    case overIncome
    case savings

    static func expense(isActive: Bool) -> Accent {
        isActive ? .expenses : .neutral
    }

    var color: Color {
        switch self {
        case .available: .green
        case .expenses: .orange
        case .income, .neutral: .gray
        case .overIncome: .critical
        case .savings: .blue
        }
    }

    var fill: Color {
        switch self {
        case .expenses: Color.orange.mix(with: .red, by: 0.25).mix(with: .black, by: 0.08)
        case .available, .income, .neutral, .overIncome, .savings: color
        }
    }

    var glow: Gradient {
        switch self {
        case .available: Gradient(colors: [.mint, .green, .mint])
        case .expenses: Gradient(colors: [.yellow, .orange, .red.mix(with: .orange, by: 0.5)])
        case .income:
            Gradient(stops: [
                .init(color: .orange, location: 0),
                .init(color: .clear, location: 0.3),
                .init(color: .green, location: 0.5),
                .init(color: .clear, location: 0.7),
                .init(color: .blue, location: 1),
            ])
        case .neutral: Gradient(colors: [.gray, .gray.mix(with: .white, by: 0.4), .gray])
        case .overIncome: Gradient(colors: [.red, .pink, .red])
        case .savings: Gradient(colors: [.blue, .cyan, .blue])
        }
    }

    var gradient: Gradient {
        switch self {
        case .available: Gradient(colors: [.green.mix(with: .white, by: 0.25), .green])
        case .expenses: Gradient(colors: [.orange.mix(with: .yellow, by: 0.3), .orange])
        case .income, .neutral: Gradient(colors: [.gray, .gray])
        case .overIncome: Gradient(colors: [.red, .red])
        case .savings: Gradient(colors: [.cyan, .blue])
        }
    }
}

extension Color {
    static let critical = Color(red: 1, green: 0.412, blue: 0.38)
}
