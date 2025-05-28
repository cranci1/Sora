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
    
    var body: some View {
        Group {
            if let module = moduleManager.modules.first(where: { $0.id.uuidString == bookmark.moduleId }) {
                BookmarkLink(
                    bookmark: bookmark,
                    module: module
                )
            }
        }
    }
}
 
