//
//  LibraryView.swift
//  Sora
//
//  Created by Francesco on 05/01/25.
//

import SwiftUI
import Kingfisher
import UIKit

struct LibraryView: View {
    @EnvironmentObject private var libraryManager: LibraryManager
    @EnvironmentObject private var moduleManager: ModuleManager
    
    @AppStorage("mediaColumnsPortrait") private var mediaColumnsPortrait: Int = 2
    @AppStorage("mediaColumnsLandscape") private var mediaColumnsLandscape: Int = 4
    
    @Environment(\.verticalSizeClass) var verticalSizeClass
    
    @State private var selectedBookmark: LibraryItem? = nil
    @State private var isDetailActive: Bool = false
    
    @State private var continueWatchingItems: [ContinueWatchingItem] = []
    @State private var isLandscape: Bool = UIDevice.current.orientation.isLandscape
    @State private var selectedTab: Int = 0
    
    private let columns = [
        GridItem(.adaptive(minimum: 150), spacing: 12)
    ]
    
    private var columnsCount: Int {
        if UIDevice.current.userInterfaceIdiom == .pad {
            let isLandscape = UIScreen.main.bounds.width > UIScreen.main.bounds.height
            return isLandscape ? mediaColumnsLandscape : mediaColumnsPortrait
        } else {
            return verticalSizeClass == .compact ? mediaColumnsLandscape : mediaColumnsPortrait
        }
    }
    
    private var cellWidth: CGFloat {
        let keyWindow = UIApplication.shared.connectedScenes
            .compactMap { ($0 as? UIWindowScene)?.windows.first(where: { $0.isKeyWindow }) }
            .first
        let safeAreaInsets = keyWindow?.safeAreaInsets ?? .zero
        let safeWidth = UIScreen.main.bounds.width - safeAreaInsets.left - safeAreaInsets.right
        let totalSpacing: CGFloat = 16 * CGFloat(columnsCount + 1)
        let availableWidth = safeWidth - totalSpacing
        return availableWidth / CGFloat(columnsCount)
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        HStack {
                            HStack(spacing: 4) {
                                Image(systemName: "play.fill")
                                    .font(.subheadline)
                                Text("Continue Watching")
                                    .font(.title3)
                                    .fontWeight(.regular)
                            }
                            
                            Spacer()
                            
                            NavigationLink(destination: AllWatchingView()) {
                                Text("View All")
                                    .font(.subheadline)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 6)
                                    .background(Color.gray.opacity(0.2))
                                    .cornerRadius(15)
                            }
                        }
                        .padding(.horizontal, 20)
                        
                        if continueWatchingItems.isEmpty {
                            VStack(spacing: 8) {
                                Image(systemName: "play.circle")
                                    .font(.largeTitle)
                                    .foregroundColor(.secondary)
                                Text("No items to continue watching.")
                                    .font(.headline)
                                Text("Recently watched content will appear here.")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            .padding()
                            .frame(maxWidth: .infinity)
                        } else {
                            ContinueWatchingSection(items: $continueWatchingItems, markAsWatched: { item in
                                markContinueWatchingItemAsWatched(item: item)
                            }, removeItem: { item in
                                removeContinueWatchingItem(item: item)
                            })
                        }

                        HStack {
                            HStack(spacing: 4) {
                                Image(systemName: "bookmark.fill")
                                    .font(.subheadline)
                                Text("Bookmarks")
                                    .font(.title3)
                                    .fontWeight(.regular)
                            }
                            
                            Spacer()
                            
                            NavigationLink(destination: BookmarksDetailView(bookmarks: $libraryManager.bookmarks)) {
                                Text("View All")
                                    .font(.subheadline)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 6)
                                    .background(Color.gray.opacity(0.2))
                                    .cornerRadius(15)
                            }
                        }
                        .padding(.horizontal, 20)

                        
                        BookmarksSection(
                            selectedBookmark: $selectedBookmark,
                            isDetailActive: $isDetailActive
                        )
                        
                        Spacer().frame(height: 100)
                        
                        NavigationLink(
                            destination: Group {
                                if let bookmark = selectedBookmark,
                                   let module = moduleManager.modules.first(where: { $0.id.uuidString == bookmark.moduleId }) {
                                    MediaInfoView(title: bookmark.title,
                                                  imageUrl: bookmark.imageUrl,
                                                  href: bookmark.href,
                                                  module: module)
                                } else {
                                    Text("No Data Available")
                                }
                            },
                            isActive: $isDetailActive
                        ) {
                            EmptyView()
                        }
                    }
                    .padding(.vertical, 20)
                }
                .navigationTitle("‎‎ Library")
                .onAppear {
                    fetchContinueWatching()
                }
            }
        }
        .navigationViewStyle(StackNavigationViewStyle())
    }
    
    private func fetchContinueWatching() {
        continueWatchingItems = ContinueWatchingManager.shared.fetchItems()
    }
    
    private func markContinueWatchingItemAsWatched(item: ContinueWatchingItem) {
        let key = "lastPlayedTime_\(item.fullUrl)"
        let totalKey = "totalTime_\(item.fullUrl)"
        UserDefaults.standard.set(99999999.0, forKey: key)
        UserDefaults.standard.set(99999999.0, forKey: totalKey)
        ContinueWatchingManager.shared.remove(item: item)
        continueWatchingItems.removeAll { $0.id == item.id }
    }
    
    private func removeContinueWatchingItem(item: ContinueWatchingItem) {
        ContinueWatchingManager.shared.remove(item: item)
        continueWatchingItems.removeAll { $0.id == item.id }
    }
    
    private func updateOrientation() {
        DispatchQueue.main.async {
            isLandscape = UIDevice.current.orientation.isLandscape
        }
    }
    
    private func determineColumns() -> Int {
        if UIDevice.current.userInterfaceIdiom == .pad {
            return isLandscape ? mediaColumnsLandscape : mediaColumnsPortrait
        } else {
            return verticalSizeClass == .compact ? mediaColumnsLandscape : mediaColumnsPortrait
        }
    }
}

struct ContinueWatchingSection: View {
    @Binding var items: [ContinueWatchingItem]
    var markAsWatched: (ContinueWatchingItem) -> Void
    var removeItem: (ContinueWatchingItem) -> Void
    
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(Array(items.reversed().prefix(5))) { item in
                    ContinueWatchingCell(item: item, markAsWatched: {
                        markAsWatched(item)
                    }, removeItem: {
                        removeItem(item)
                    })
                }
            }
            .padding(.horizontal, 20)
        }
    }
}

struct ContinueWatchingCell: View {
    let item: ContinueWatchingItem
    var markAsWatched: () -> Void
    var removeItem: () -> Void
    
    @State private var currentProgress: Double = 0.0
    
    var body: some View {
        Button(action: {
            if UserDefaults.standard.string(forKey: "externalPlayer") == "Default" {
                let videoPlayerViewController = VideoPlayerViewController(module: item.module)
                videoPlayerViewController.streamUrl = item.streamUrl
                videoPlayerViewController.fullUrl = item.fullUrl
                videoPlayerViewController.episodeImageUrl = item.imageUrl
                videoPlayerViewController.episodeNumber = item.episodeNumber
                videoPlayerViewController.mediaTitle = item.mediaTitle
                videoPlayerViewController.subtitles = item.subtitles ?? ""
                videoPlayerViewController.aniListID = item.aniListID ?? 0
                videoPlayerViewController.modalPresentationStyle = .fullScreen
                
                if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                   let rootVC = windowScene.windows.first?.rootViewController {
                    findTopViewController.findViewController(rootVC).present(videoPlayerViewController, animated: true, completion: nil)
                }
            } else {
                let customMediaPlayer = CustomMediaPlayerViewController(
                    module: item.module,
                    urlString: item.streamUrl,
                    fullUrl: item.fullUrl,
                    title: item.mediaTitle,
                    episodeNumber: item.episodeNumber,
                    onWatchNext: { },
                    subtitlesURL: item.subtitles,
                    aniListID: item.aniListID ?? 0,
                    episodeImageUrl: item.imageUrl,
                    headers: item.headers ?? nil
                )
                customMediaPlayer.modalPresentationStyle = .fullScreen
                
                if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                   let rootVC = windowScene.windows.first?.rootViewController {
                    findTopViewController.findViewController(rootVC).present(customMediaPlayer, animated: true, completion: nil)
                }
            }
        }) {
            ZStack(alignment: .bottomLeading) {
                KFImage(URL(string: item.imageUrl.isEmpty ? "https://raw.githubusercontent.com/cranci1/Sora/refs/heads/main/assets/banner2.png" : item.imageUrl))
                    .placeholder {
                        RoundedRectangle(cornerRadius: 10)
                            .fill(Color.gray.opacity(0.3))
                            .frame(width: 280, height: 157.03)
                            .shimmering()
                    }
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 280, height: 157.03)
                    .cornerRadius(10)
                    .clipped()
                    .overlay(
                        ZStack {
                            ProgressiveBlurView()
                                .cornerRadius(10, corners: [.bottomLeft, .bottomRight])
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Spacer()
                                Text(item.mediaTitle)
                                    .font(.headline)
                                    .foregroundColor(.white)
                                    .lineLimit(1)
                                
                                HStack {
                                    Text("Episode \(item.episodeNumber)")
                                        .font(.subheadline)
                                        .foregroundColor(.white.opacity(0.9))
                                    
                                    Spacer()
                                    
                                    Text("\(Int(item.progress * 100))% seen")
                                        .font(.caption)
                                        .foregroundColor(.white.opacity(0.9))
                                }
                            }
                            .padding(10)
                        },
                        alignment: .bottom
                    )
                    .overlay(
                        ZStack {
                            Circle()
                                .fill(Color.black.opacity(0.5))
                                .frame(width: 28, height: 28)
                                .overlay(
                                    KFImage(URL(string: item.module.metadata.iconUrl))
                                        .resizable()
                                        .scaledToFill()
                                        .frame(width: 32, height: 32)
                                        .clipShape(Circle())
                                )
                        }
                        .padding(8),
                        alignment: .topLeading
                    )
            }
            .frame(width: 280, height: 157.03)
        }
        .contextMenu {
            Button(action: { markAsWatched() }) {
                Label("Mark as Watched", systemImage: "checkmark.circle")
            }
            Button(role: .destructive, action: { removeItem() }) {
                Label("Remove Item", systemImage: "trash")
            }
        }
        .onAppear {
            updateProgress()
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)) { _ in
            updateProgress()
        }
    }
    
    private func updateProgress() {
        let lastPlayedTime = UserDefaults.standard.double(forKey: "lastPlayedTime_\(item.fullUrl)")
        let totalTime = UserDefaults.standard.double(forKey: "totalTime_\(item.fullUrl)")
        
        if totalTime > 0 {
            let ratio = lastPlayedTime / totalTime
            currentProgress = max(0, min(ratio, 1))
        } else {
            currentProgress = max(0, min(item.progress, 1))
        }
    }
}


struct RoundedCorner: Shape {
    var radius: CGFloat = .infinity
    var corners: UIRectCorner = .allCorners

    func path(in rect: CGRect) -> Path {
        let path = UIBezierPath(
            roundedRect: rect,
            byRoundingCorners: corners,
            cornerRadii: CGSize(width: radius, height: radius)
        )
        return Path(path.cgPath)
    }
}

extension View {
    func cornerRadius(_ radius: CGFloat, corners: UIRectCorner) -> some View {
        clipShape(RoundedCorner(radius: radius, corners: corners))
    }
}

struct BookmarksSection: View {
    @EnvironmentObject private var libraryManager: LibraryManager
    @EnvironmentObject private var moduleManager: ModuleManager
    
    @Binding var selectedBookmark: LibraryItem?
    @Binding var isDetailActive: Bool
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            if libraryManager.bookmarks.isEmpty {
                EmptyBookmarksView()
            } else {
                BookmarksGridView(
                    selectedBookmark: $selectedBookmark,
                    isDetailActive: $isDetailActive
                )
            }
        }
    }
}

struct EmptyBookmarksView: View {
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: "magazine")
                .font(.largeTitle)
                .foregroundColor(.secondary)
            Text("You have no items saved.")
                .font(.headline)
            Text("Bookmark items for an easier access later.")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding()
        .frame(maxWidth: .infinity)
    }
}

struct BookmarksGridView: View {
    @EnvironmentObject private var libraryManager: LibraryManager
    @EnvironmentObject private var moduleManager: ModuleManager
    
    @Binding var selectedBookmark: LibraryItem?
    @Binding var isDetailActive: Bool
    
    private var recentBookmarks: [LibraryItem] {
        Array(libraryManager.bookmarks.prefix(5))
    }
    
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(recentBookmarks) { item in
                    BookmarkItemView(
                        item: item,
                        selectedBookmark: $selectedBookmark,
                        isDetailActive: $isDetailActive
                    )
                }
            }
            .padding(.horizontal, 20)
        }
    }
}

struct BookmarkItemView: View {
    @EnvironmentObject private var libraryManager: LibraryManager
    @EnvironmentObject private var moduleManager: ModuleManager
    
    let item: LibraryItem
    @Binding var selectedBookmark: LibraryItem?
    @Binding var isDetailActive: Bool
    
    var body: some View {
        if let module = moduleManager.modules.first(where: { $0.id.uuidString == item.moduleId }) {
            Button(action: {
                selectedBookmark = item
                isDetailActive = true
            }) {
                VStack(alignment: .leading) {
                    ZStack {
                        KFImage(URL(string: item.imageUrl))
                            .placeholder {
                                RoundedRectangle(cornerRadius: 10)
                                    .fill(Color.gray.opacity(0.3))
                                    .aspectRatio(2/3, contentMode: .fit)
                                    .shimmering()
                            }
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: 162, height: 243)
                            .cornerRadius(10)
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
                    }
                }
                .frame(width: 162)
            }
            .contextMenu {
                Button(role: .destructive, action: {
                    libraryManager.removeBookmark(item: item)
                }) {
                    Label("Remove from Bookmarks", systemImage: "trash")
                }
            }
        }
    }
}
