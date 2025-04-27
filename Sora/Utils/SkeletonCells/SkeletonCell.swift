//
//  SkeletonCell.swift
//  Sora
//
//  Created by Francesco on 09/02/25.
//

import SwiftUI

enum SkeletonCellType {
    // unused !? ( legacy code from HomeSkeletonCell ) 
    case home

    case search
    case explore
}

struct SkeletonCell: View {
    let type: SkeletonCellType
    let cellWidth: CGFloat

    var body: some View {
        VStack(alignment: type == .home ? .center : .leading, spacing: type == .home ? 0 : 8) {
            RoundedRectangle(cornerRadius: 10)
                .fill(Color.gray.opacity(0.3))
                .frame(width: cellWidth, height: cellWidth * 1.5)
                .cornerRadius(10)
                .shimmering()

            RoundedRectangle(cornerRadius: 5)
                .fill(Color.gray.opacity(0.3))
                .frame(width: cellWidth, height: 20)
                .padding(.top, type == .home ? 4 : 0)
                .shimmering()
        }
    }
}
