//
//  SyncStatusLabel.swift
//  Overhead
//
//  Created by Lorenzo Mazzarotto on 24/07/26.
//

import SwiftUI

enum SyncStatus: Equatable {
    case offline
    case synced
    case syncing
}

struct SyncStatusLabel: View {
    let expenseCount: Int
    let status: SyncStatus

    var body: some View {
        HStack(spacing: 5) {
            if status == .syncing {
                ProgressView()
                    .controlSize(.mini)
            }
            Text(text)
        }
        .font(.subheadline)
        .foregroundStyle(.secondary)
        .animation(.default, value: status)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityLabel)
    }

    private var accessibilityLabel: Text {
        guard status == .syncing else { return Text(text) }
        return Text("Syncing, \(Text(text))")
    }

    private var text: LocalizedStringKey {
        switch status {
        case .offline:
            "No Internet"
        case .synced, .syncing:
            expenseCount == 0 ? "No Expenses" : "^[\(expenseCount) Expense](inflect: true)"
        }
    }
}

#Preview("In Toolbar") {
    NavigationStack {
        Color(.systemGroupedBackground)
            .ignoresSafeArea()
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .title) {
                    VStack(alignment: .leading, spacing: 0) {
                        Text("Expenses")
                            .font(.title)
                            .fontWeight(.bold)
                        SyncStatusLabel(expenseCount: 24, status: .syncing)
                    }
                }
            }
    }
}

#Preview("States") {
    VStack(alignment: .leading, spacing: 16) {
        SyncStatusLabel(expenseCount: 24, status: .synced)
        SyncStatusLabel(expenseCount: 1, status: .synced)
        SyncStatusLabel(expenseCount: 0, status: .synced)
        SyncStatusLabel(expenseCount: 24, status: .syncing)
        SyncStatusLabel(expenseCount: 24, status: .offline)
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .groupedBackground()
}
