//
//  SearchResultsGrid.swift
//  Sora
//
//  Created by paul on 28/05/25.
//

import NukeUI
import SwiftUI

struct SearchResultsGrid: View {
    @AppStorage("mediaColumnsPortrait") private var mediaColumnsPortrait: Int = 2
    @AppStorage("mediaColumnsLandscape") private var mediaColumnsLandscape: Int = 4
    @Environment(\.verticalSizeClass) var verticalSizeClass
    @EnvironmentObject private var libraryManager: LibraryManager
    @EnvironmentObject private var moduleManager: ModuleManager
    @State private var showBookmarkToast: Bool = false
    @State private var toastMessage: String = ""
    
    let items: [SearchItem]
    let columns: [GridItem]
    let selectedModule: ScrapingModule
    let cellWidth: CGFloat
    
    private var columnsCount: Int {
        if UIDevice.current.userInterfaceIdiom == .pad {
            let isLandscape = UIScreen.main.bounds.width > UIScreen.main.bounds.height
            return isLandscape ? mediaColumnsLandscape : mediaColumnsPortrait
        } else {
            return verticalSizeClass == .compact ? mediaColumnsLandscape : mediaColumnsPortrait
        }
    }
    
    var body: some View {
        ZStack {
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: columnsCount), spacing: 12) {
                ForEach(items) { item in
                    NavigationLink(destination: MediaInfoView(title: item.title, imageUrl: item.imageUrl, href: item.href, module: selectedModule)) {
                        ZStack {
                            LazyImage(url: URL(string: item.imageUrl)) { state in
                                if let uiImage = state.imageContainer?.image {
                                    Image(uiImage: uiImage)
                                        .resizable()
                                        .aspectRatio(contentMode: .fill)
                                        .frame(width: cellWidth, height: cellWidth * 1.5)
                                        .cornerRadius(12)
                                        .clipped()
                                } else {
                                    Rectangle()
                                        .fill(.tertiary)
                                        .frame(width: cellWidth, height: cellWidth * 1.5)
                                        .cornerRadius(12)
                                        .clipped()
                                }
                            }
                            
                            VStack {
                                Spacer()
                                HStack {
                                    Text(item.title)
                                        .lineLimit(2)
                                        .foregroundColor(.white)
                                        .multilineTextAlignment(.leading)
                                    Spacer()
                                }
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
                            .frame(width: cellWidth)
                        }
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .padding(4)
                    }
                    .id(item.href)
                    .contextMenu {
                        Button(action: {
                            let isBookmarked = libraryManager.isBookmarked(href: item.href, moduleName: selectedModule.metadata.sourceName)
                            libraryManager.toggleBookmark(
                                title: item.title,
                                imageUrl: item.imageUrl,
                                href: item.href,
                                moduleId: selectedModule.id.uuidString,
                                moduleName: selectedModule.metadata.sourceName
                            )
                            DropManager.shared.showDrop(
                                title: isBookmarked ? "Removed from Bookmarks" : "Bookmarked!",
                                subtitle: item.title,
                                duration: 1.0,
                                icon: UIImage(systemName: isBookmarked ? "bookmark.slash" : "bookmark.fill")
                            )
                        }) {
                            Label(libraryManager.isBookmarked(href: item.href, moduleName: selectedModule.metadata.sourceName) ? "Remove Bookmark" : "Bookmark",
                                  systemImage: libraryManager.isBookmarked(href: item.href, moduleName: selectedModule.metadata.sourceName) ? "bookmark.slash" : "bookmark")
                        }
                    }
                }
            }
            .padding(.top)
            .padding()
            
            if showBookmarkToast {
                VStack {
                    Spacer()
                    Text(toastMessage)
                        .font(.headline)
                        .padding()
                        .background(Color.black.opacity(0.8))
                        .foregroundColor(.white)
                        .cornerRadius(12)
                        .padding(.bottom, 40)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
                .onAppear {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
                        withAnimation { showBookmarkToast = false }
                    }
                }
            }
        }
        .sheet(isPresented: $libraryManager.isShowingCollectionPicker) {
            if let bookmark = libraryManager.bookmarkToAdd {
                CollectionPickerView(bookmark: bookmark)
            }
        }
    }
}
