//
//  MediaInfoView.swift
//  Sora
//
//  Created by paul on 28/05/25.
//

import SwiftUI

struct BookmarkGridItemView: View {
    let bookmark: LibraryItem
    let moduleManager: ModuleManager
    let isSelecting: Bool
    @Binding var selectedBookmarks: Set<LibraryItem.ID>
    
    var isSelected: Bool {
        selectedBookmarks.contains(bookmark.id)
    }
    
    var body: some View {
        Group {
            if let module = moduleManager.modules.first(where: { $0.id.uuidString == bookmark.moduleId }) {
                if isSelecting {
                    Button(action: {
                        if isSelected {
                            selectedBookmarks.remove(bookmark.id)
                        } else {
                            selectedBookmarks.insert(bookmark.id)
                        }
                    }) {
                        ZStack(alignment: .topTrailing) {
                            BookmarkCell(bookmark: bookmark)
                            if isSelected {
                                Image(systemName: "checkmark.circle.fill")
                                    .resizable()
                                    .frame(width: 32, height: 32)
                                    .foregroundColor(.accentColor)
                                    .background(Color.white.clipShape(Circle()).opacity(0.8))
                                    .offset(x: -8, y: 8)
                            }
                        }
                    }
                } else {
                    BookmarkLink(
                        bookmark: bookmark,
                        module: module
                    )
                }
            }
        }
    }
}
 
