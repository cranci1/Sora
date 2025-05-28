//
//  MediaInfoView.swift
//  Sora
//
//  Created by paul on 28/05/25.
//

import SwiftUI

struct BookmarkLink: View {
    let bookmark: LibraryItem
    let module: Module
    
    var body: some View {
        NavigationLink(destination: MediaInfoView(
            title: bookmark.title,
            imageUrl: bookmark.imageUrl,
            href: bookmark.href,
            module: module
        )) {
            BookmarkCell(bookmark: bookmark)
        }
    }
} 
