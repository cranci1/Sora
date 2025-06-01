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
        ZStack(alignment: .bottom) {
            RoundedRectangle(cornerRadius: 10)
                .fill(Color.gray.opacity(0.3))
                .frame(width: cellWidth, height: cellWidth * 1.5)
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
        ZStack(alignment: .bottom) {
            RoundedRectangle(cornerRadius: 10)
                .fill(Color.gray.opacity(0.3))
                .frame(width: cellWidth, height: cellWidth * 1.5)
                .shimmering()
            
            RoundedRectangle(cornerRadius: 5)
                .fill(Color.gray.opacity(0.3))
                .frame(width: cellWidth, height: 20)
                .shimmering()
        }
    }
}
