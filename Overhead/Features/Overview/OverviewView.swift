//
//  OverviewView.swift
//  Overhead
//
//  Created by Lorenzo Mazzarotto on 01/10/26.
//

import SwiftUI

struct OverviewView: View {
    var body: some View {
        NavigationStack {
            ContentUnavailableView("Coming Soon", systemImage: "square.grid.2x2")
                .groupedBackground()
                .navigationBarTitleDisplayMode(.inline)
                .toolbarRole(.editor)
                .toolbar {
                    ToolbarItem(placement: .title) {
                        Text("Overview")
                            .font(.title)
                            .fontWeight(.bold)
                    }
                }
        }
    }
}

#Preview {
    OverviewView()
}
