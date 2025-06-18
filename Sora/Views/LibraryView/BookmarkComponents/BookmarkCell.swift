//
//  BookmarkCell.swift
//  Sora
//
//  Created by paul on 18/06/25.
//

import SwiftUI
import NukeUI

struct BookmarkCell: View {
    let bookmark: LibraryItem
    @EnvironmentObject private var moduleManager: ModuleManager
    @EnvironmentObject private var libraryManager: LibraryManager
    
    var body: some View {
        if let module = moduleManager.modules.first(where: { $0.id.uuidString == bookmark.moduleId }) {
            ZStack {
                LazyImage(url: URL(string: bookmark.imageUrl)) { state in
                    if let uiImage = state.imageContainer?.image {
                        Image(uiImage: uiImage)
                            .resizable()
                            .aspectRatio(0.72, contentMode: .fill)
                            .frame(width: 162, height: 243)
                            .cornerRadius(12)
                            .clipped()
                    } else {
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.gray.opacity(0.3))
                            .frame(width: 162, height: 243)
                    }
                }
                .overlay(
                    ZStack {
                        Circle()
                            .fill(Color.black.opacity(0.5))
                            .frame(width: 28, height: 28)
                            .overlay(
                                LazyImage(url: URL(string: module.metadata.iconUrl)) { state in
                                    if let uiImage = state.imageContainer?.image {
                                        Image(uiImage: uiImage)
                                            .resizable()
                                            .scaledToFill()
                                            .frame(width: 32, height: 32)
                                            .clipShape(Circle())
                                    } else {
                                        Circle()
                                            .fill(Color.gray.opacity(0.3))
                                            .frame(width: 32, height: 32)
                                    }
                                }
                            )
                    }
                    .padding(8),
                    alignment: .topLeading
                )
                
                VStack {
                    Spacer()
                    Text(bookmark.title)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .lineLimit(2)
                        .foregroundColor(.white)
                        .padding(12)
                        .background(
                            LinearGradient(
                                colors: [
                                    .black.opacity(0.7),
                                    .black.opacity(0.0)
                                ],
                                startPoint: .bottom,
                                endPoint: .top
                            )
                            .shadow(color: .black, radius: 4, x: 0, y: 2)
                        )
                }
                .frame(width: 162)
            }
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .padding(4)
            .contextMenu {
                Button(role: .destructive, action: {
                    // Find which collection contains this bookmark
                    for collection in libraryManager.collections {
                        if collection.bookmarks.contains(where: { $0.id == bookmark.id }) {
                            libraryManager.removeBookmarkFromCollection(bookmarkId: bookmark.id, collectionId: collection.id)
                            break
                        }
                    }
                }) {
                    Label("Remove from Bookmarks", systemImage: "trash")
                }
            }
        }
    }
} 