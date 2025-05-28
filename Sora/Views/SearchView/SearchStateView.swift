//
//  SearchStateView.swift
//  Sora
//
//  Created by Francesco on 27/01/25.
//

import SwiftUI

struct SearchStateView: View {
    let isSearching: Bool
    let hasNoResults: Bool
    let columnsCount: Int
    let cellWidth: CGFloat
    
    var body: some View {
        if isSearching {
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 16), count: columnsCount), spacing: 16) {
                ForEach(0..<columnsCount*4, id: \.self) { _ in
                    SearchSkeletonCell(cellWidth: cellWidth)
                }
            }
            .padding(.top)
            .padding()
        } else if hasNoResults {
            VStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .font(.largeTitle)
                    .foregroundColor(.secondary)
                Text("No Results Found")
                    .font(.headline)
                Text("Try different keywords")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding()
            .frame(maxWidth: .infinity)
            .padding(.top)
        }
    }
} 