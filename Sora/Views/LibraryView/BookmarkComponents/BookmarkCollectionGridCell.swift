//
//  BookmarkCollectionGridCell.swift
//  Sora
//
//  Created by paul on 18/06/25.
//

import NukeUI
import SwiftUI

struct BookmarkCollectionGridCell: View {
    let collection: BookmarkCollection
    let width: CGFloat
    let height: CGFloat
    
    private var recentBookmarks: [LibraryItem] {
        Array(collection.bookmarks.prefix(4))
    }
    
    var body: some View {
        let gap: CGFloat = 2
        let cellWidth = (width - gap) / 2
        let cellHeight = (height - gap) / 2
        VStack(alignment: .leading, spacing: 8) {
            ZStack {
                if recentBookmarks.isEmpty {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.gray.opacity(0.3))
                        .frame(width: width, height: height)
                        .overlay(
                            Image(systemName: "folder.fill")
                                .resizable()
                                .scaledToFit()
                                .frame(width: width/3)
                                .foregroundColor(.gray.opacity(0.5))
                        )
                } else {
                    LazyVGrid(
                        columns: [
                            GridItem(.flexible(), spacing: gap),
                            GridItem(.flexible(), spacing: gap)
                        ],
                        spacing: gap
                    ) {
                        ForEach(0..<4) { index in
                            if index < recentBookmarks.count {
                                LazyImage(url: URL(string: recentBookmarks[index].imageUrl)) { state in
                                    if let image = state.imageContainer?.image {
                                        Image(uiImage: image)
                                            .resizable()
                                            .aspectRatio(contentMode: .fill)
                                            .frame(width: cellWidth, height: cellHeight)
                                            .clipped()
                                    } else {
                                        Rectangle()
                                            .fill(Color.gray.opacity(0.3))
                                            .frame(width: cellWidth, height: cellHeight)
                                    }
                                }
                            } else {
                                Rectangle()
                                    .fill(Color.gray.opacity(0.3))
                                    .frame(width: cellWidth, height: cellHeight)
                            }
                        }
                    }
                    .frame(width: width, height: height)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(collection.name)
                    .font(.headline)
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .layoutPriority(1)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Text("\(collection.bookmarks.count) items")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .frame(width: width, height: height)
            .padding(.horizontal, 4)
        }
    }
}
