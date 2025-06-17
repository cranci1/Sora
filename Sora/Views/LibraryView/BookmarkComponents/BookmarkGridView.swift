//
//  MediaInfoView.swift
//  Sora
//
//  Created by paul on 28/05/25.
//

import SwiftUI

struct BookmarkGridView: View {
    let bookmarks: [LibraryItem]
    let moduleManager: ModuleManager
    let isSelecting: Bool
    @Binding var selectedBookmarks: Set<LibraryItem.ID>
    
    private let columns = [
        GridItem(.adaptive(minimum: 150))
    ]
    
    var body: some View {
        ScrollView(showsIndicators: false) {
            LazyVGrid(columns: columns, spacing: 16) {
                ForEach(bookmarks) { bookmark in
                    BookmarkGridItemView(
                        bookmark: bookmark,
                        moduleManager: moduleManager,
                        isSelecting: isSelecting,
                        selectedBookmarks: $selectedBookmarks
                    )
                }
            }
            .padding()
            .scrollViewBottomPadding()
        }
    }
} 
