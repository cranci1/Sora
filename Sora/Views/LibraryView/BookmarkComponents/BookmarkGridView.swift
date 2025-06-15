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
    
    private let columns = [
        GridItem(.adaptive(minimum: 150))
    ]
    
    var body: some View {
        ScrollView(showsIndicators: false) {
            LazyVGrid(columns: columns, spacing: 16) {
                ForEach(bookmarks) { bookmark in
                    BookmarkGridItemView(
                        bookmark: bookmark,
                        moduleManager: moduleManager
                    )
                }
            }
            .padding()
            .scrollViewBottomPadding()
        }
    }
} 
