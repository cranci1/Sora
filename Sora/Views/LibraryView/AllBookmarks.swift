//
//  AllBookmarks.swift
//  Sulfur
//
//  Created by paul on 29/04/2025.
//

import SwiftUI
import Kingfisher
import UIKit

struct BookmarksDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var libraryManager: LibraryManager
    @EnvironmentObject private var moduleManager: ModuleManager
    
    @Binding var bookmarks: [LibraryItem]
    @State private var sortOption: SortOption = .dateAdded
    
    let columns = [GridItem(.adaptive(minimum: 150))]
    
    enum SortOption: String, CaseIterable {
        case dateAdded = "Date Added"
        case title = "Title"
        case source = "Source"
    }
    
    var sortedBookmarks: [LibraryItem] {
        switch sortOption {
        case .dateAdded:
            return bookmarks
        case .title:
            return bookmarks.sorted { $0.title.lowercased() < $1.title.lowercased() }
        case .source:
            return bookmarks.sorted { item1, item2 in
                let module1 = moduleManager.modules.first { $0.id.uuidString == item1.moduleId }
                let module2 = moduleManager.modules.first { $0.id.uuidString == item2.moduleId }
                return (module1?.metadata.sourceName ?? "") < (module2?.metadata.sourceName ?? "")
            }
        }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 8) {
                Button(action: {
                    dismiss()
                }) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 24))
                        .foregroundColor(.primary)
                }
                
                Text("All Bookmarks")
                    .font(.title3)
                    .fontWeight(.bold)
                
                Spacer()
                
                Menu {
                    ForEach(SortOption.allCases, id: \.self) { option in
                        Button {
                            sortOption = option
                        } label: {
                            HStack {
                                Text(option.rawValue)
                                if option == sortOption {
                                    Image(systemName: "checkmark")
                                        .foregroundColor(.accentColor)
                                }
                            }
                        }
                    }
                } label: {
                    Image(systemName: "line.3.horizontal.decrease.circle")
                        .resizable()
                        .frame(width: 36, height: 36)
                        .foregroundColor(.accentColor)
                }
            }
            .padding(.horizontal)
            .padding(.top)
            
            ScrollView {
                LazyVGrid(columns: columns, spacing: 16) {
                    ForEach(sortedBookmarks) { bookmark in
                        if let module = moduleManager.modules.first(where: { $0.id.uuidString == bookmark.moduleId }) {
                            NavigationLink(destination: MediaInfoView(
                                title: bookmark.title,
                                imageUrl: bookmark.imageUrl,
                                href: bookmark.href,
                                module: module)) {
                                    BookmarkCell(bookmark: bookmark)
                                }
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 20)
            }
        }
        .navigationBarBackButtonHidden(true)
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            // Enable swipe back gesture
            if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
               let window = windowScene.windows.first,
               let navigationController = window.rootViewController?.children.first as? UINavigationController {
                navigationController.interactivePopGestureRecognizer?.isEnabled = true
                navigationController.interactivePopGestureRecognizer?.delegate = nil
            }
        }
    }
}

struct BookmarkCell: View {
    let bookmark: LibraryItem
    @EnvironmentObject private var moduleManager: ModuleManager
    
    var body: some View {
        if let module = moduleManager.modules.first(where: { $0.id.uuidString == bookmark.moduleId }) {
            ZStack {
                KFImage(URL(string: bookmark.imageUrl))
                    .resizable()
                    .aspectRatio(0.72, contentMode: .fill)
                    .frame(width: 162, height: 243)
                    .cornerRadius(12)
                    .clipped()
                    .overlay(
                        ZStack {
                            Circle()
                                .fill(Color.black.opacity(0.5))
                                .frame(width: 28, height: 28)
                                .overlay(
                                    KFImage(URL(string: module.metadata.iconUrl))
                                        .resizable()
                                        .scaledToFill()
                                        .frame(width: 32, height: 32)
                                        .clipShape(Circle())
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
        }
    }
}
