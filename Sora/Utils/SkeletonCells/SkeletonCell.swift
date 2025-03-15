//
//  SkeletonCell.swift
//  Sora
//
//  Created by Francesco on 09/02/25.
//

import SwiftUI

struct HomeSkeletonCell: View {
    let cellWidth: CGFloat
    
    var body: some View {
        VStack {
            RoundedRectangle(cornerRadius: 10)
                .fill(Color.gray.opacity(0.3))
                .frame(width: cellWidth, height: cellWidth * 1.5) // Maintains 2:3 aspect ratio
                .cornerRadius(10)
                .shimmering()
            
            RoundedRectangle(cornerRadius: 5)
                .fill(Color.gray.opacity(0.3))
                .frame(width: cellWidth, height: 20)
                .padding(.top, 4)
                .shimmering()
        }
    }
}

struct SearchSkeletonCell: View {
    let cellWidth: CGFloat
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            RoundedRectangle(cornerRadius: 10)
                .fill(Color.gray.opacity(0.3))
                .frame(width: cellWidth, height: cellWidth * 1.5) // Maintains 2:3 aspect ratio
                .shimmering()
            RoundedRectangle(cornerRadius: 5)
                .fill(Color.gray.opacity(0.3))
                .frame(width: cellWidth, height: 20)
                .shimmering()
        }
    }
}
