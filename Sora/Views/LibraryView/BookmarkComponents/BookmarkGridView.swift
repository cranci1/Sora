//
//  MediaInfoView.swift
//  Sora
//
//  Created by paul on 28/05/25.
//

import SwiftUI

struct BookmarkGridView: View {
    @EnvironmentObject private var libraryManager: LibraryManager
    @EnvironmentObject private var moduleManager: ModuleManager
    
    let bookmarks: [LibraryItem]
    let isSelecting: Bool
    @Binding var selectedBookmarks: Set<LibraryItem.ID>
    
    private let columns = [
        GridItem(.adaptive(minimum: 150), spacing: 16)
    ]
    
    var body: some View {
        LazyVGrid(columns: columns, spacing: 16) {
            ForEach(bookmarks) { bookmark in
                if let module = moduleManager.modules.first(where: { $0.id.uuidString == bookmark.moduleId }) {
                    if isSelecting {
                        Button(action: {
                            if selectedBookmarks.contains(bookmark.id) {
                                selectedBookmarks.remove(bookmark.id)
                            } else {
                                selectedBookmarks.insert(bookmark.id)
                            }
                        }) {
                            NavigationLink(destination: MediaInfoView(
                                title: bookmark.title,
                                imageUrl: bookmark.imageUrl,
                                href: bookmark.href,
                                module: module
                            )) {
                                BookmarkGridItemView(item: bookmark, module: module)
                                    .overlay(
                                        selectedBookmarks.contains(bookmark.id) ?
                                        Image(systemName: "checkmark.circle.fill")
                                            .resizable()
                                            .frame(width: 32, height: 32)
                                            .foregroundColor(.accentColor)
                                            .background(Color.white.clipShape(Circle()))
                                            .padding(8)
                                        : nil,
                                        alignment: .topTrailing
                                    )
                            }
                        }
                    } else {
                        NavigationLink(destination: MediaInfoView(
                            title: bookmark.title,
                            imageUrl: bookmark.imageUrl,
                            href: bookmark.href,
                            module: module
                        )) {
                            BookmarkGridItemView(item: bookmark, module: module)
                        }
                    }
                }
            }
        }
        .padding()
    }
} 
