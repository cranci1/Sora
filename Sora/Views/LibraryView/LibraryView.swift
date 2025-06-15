//
//  LibraryView.swift
//  Sora
//
//  Created by Francesco on 05/01/25.
//

import UIKit
import NukeUI
import SwiftUI

struct LibraryView: View {
    @EnvironmentObject private var libraryManager: LibraryManager
    @EnvironmentObject private var moduleManager: ModuleManager
    @Environment(\.scenePhase) private var scenePhase
    
    @AppStorage("mediaColumnsPortrait") private var mediaColumnsPortrait: Int = 2
    @AppStorage("mediaColumnsLandscape") private var mediaColumnsLandscape: Int = 4
    
    @Environment(\.verticalSizeClass) var verticalSizeClass
    @Environment(\.horizontalSizeClass) var horizontalSizeClass
    
    @State private var selectedBookmark: LibraryItem? = nil
    @State private var isDetailActive: Bool = false
    
    @State private var continueWatchingItems: [ContinueWatchingItem] = []
    @State private var isLandscape: Bool = UIDevice.current.orientation.isLandscape
    @State private var selectedTab: Int = 0
    
    private let columns = [
        GridItem(.adaptive(minimum: 150), spacing: 12)
    ]
    
    private var columnsCount: Int {
        if UIDevice.current.userInterfaceIdiom == .pad && horizontalSizeClass == .compact {
            return verticalSizeClass == .compact ? 3 : 2
        } else if UIDevice.current.userInterfaceIdiom == .pad {
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
                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 20) {
                        Text("Library")
                            .font(.largeTitle)
                            .fontWeight(.bold)
                            .padding(.horizontal, 20)
                            .padding(.top, 20)
                        HStack {
                            HStack(spacing: 4) {
                                Image(systemName: "play.fill")
                                    .font(.subheadline)
                                Text("Continue Watching")
                                    .font(.title3)
                                    .fontWeight(.semibold)
                            }
                            
                            Spacer()
                            
                            NavigationLink(destination: AllWatchingView()) {
                                Text("View All")
                                    .font(.subheadline)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 6)
                                    .background(Color.gray.opacity(0.2))
                                    .cornerRadius(15)
                                    .gradientOutline()
                            }
                        }
                        .padding(.horizontal, 20)
                        
                        if continueWatchingItems.isEmpty {
                            VStack(spacing: 8) {
                                Image(systemName: "play.circle")
                                    .font(.largeTitle)
                                    .foregroundColor(.secondary)
                                Text("Nothing to Continue Watching")
                                    .font(.headline)
                                Text("Your recently watched content will appear here")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            .padding()
                            .frame(maxWidth: .infinity)
                        } else {
                            ContinueWatchingSection(items: $continueWatchingItems, markAsWatched: {
                                item in
                                markContinueWatchingItemAsWatched(item: item)
                            }, removeItem: {
                                item in
                                removeContinueWatchingItem(item: item)
                            })
                        }
                        
                        HStack {
                            HStack(spacing: 4) {
                                Image(systemName: "bookmark.fill")
                                    .font(.subheadline)
                                Text("Bookmarks")
                                    .font(.title3)
                                    .fontWeight(.semibold)
                            }
                            
                            Spacer()
                            
                            NavigationLink(destination: BookmarksDetailView(bookmarks: $libraryManager.bookmarks)) {
                                Text("View All")
                                    .font(.subheadline)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 6)
                                    .background(Color.gray.opacity(0.2))
                                    .cornerRadius(15)
                                    .gradientOutline()
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
                                   let module = moduleManager.modules.first(where: {
                                       $0.id.uuidString == bookmark.moduleId
                                   }) {
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
                    .padding(.bottom, 20)
                }
                .scrollViewBottomPadding()
                .deviceScaled()
                .onAppear {
                    fetchContinueWatching()
                }
                .onChange(of: scenePhase) { newPhase in
                    if newPhase == .active {
                        fetchContinueWatching()
                    }
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
        continueWatchingItems.removeAll {
            $0.id == item.id
        }
    }
    
    private func removeContinueWatchingItem(item: ContinueWatchingItem) {
        ContinueWatchingManager.shared.remove(item: item)
        continueWatchingItems.removeAll {
            $0.id == item.id
        }
    }
    
    private func updateOrientation() {
        DispatchQueue.main.async {
            isLandscape = UIDevice.current.orientation.isLandscape
        }
    }
    
    private func determineColumns() -> Int {
        if UIDevice.current.userInterfaceIdiom == .pad && horizontalSizeClass == .compact {
            return verticalSizeClass == .compact ? 3 : 2
        } else if UIDevice.current.userInterfaceIdiom == .pad {
            let isLandscape = UIScreen.main.bounds.width > UIScreen.main.bounds.height
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
            .frame(height: 157.03)
        }
    }
}

struct ContinueWatchingCell: View {
    let item: ContinueWatchingItem
    var markAsWatched: () -> Void
    var removeItem: () -> Void
    
    @State private var currentProgress: Double = 0.0
    @Environment(\.scenePhase) private var scenePhase
    
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
                    totalEpisodes: item.totalEpisodes,
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
                LazyImage(url: URL(string: item.imageUrl.isEmpty ? "https://raw.githubusercontent.com/cranci1/Sora/refs/heads/main/assets/banner2.png" : item.imageUrl)) { state in
                    if let uiImage = state.imageContainer?.image {
                        Image(uiImage: uiImage)
                            .resizable()
                            .aspectRatio(16/9, contentMode: .fill)
                            .frame(width: 280, height: 157.03)
                            .cornerRadius(10)
                            .clipped()
                    } else {
                        RoundedRectangle(cornerRadius: 10)
                            .fill(Color.gray.opacity(0.3))
                            .frame(width: 280, height: 157.03)
                            .redacted(reason: .placeholder)
                    }
                }
                .overlay(
                    ZStack {
                        
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
                        .background(
                            LinearGradient(
                                colors: [
                                    .black.opacity(0.7),
                                    .black.opacity(0.0)
                                ],
                                startPoint: .bottom,
                                endPoint: .top
                            )
                                .clipped()
                                .cornerRadius(10, corners: [.bottomLeft, .bottomRight])
                                .shadow(color: .black.opacity(0.3), radius: 3, x: 0, y: 1)
                        )
                    },
                    alignment: .bottom
                )
                .overlay(
                    ZStack {
                        if item.streamUrl.hasPrefix("file://") {
                            Image(systemName: "arrow.down.app.fill")
                                .resizable()
                                .scaledToFit()
                                .frame(width: 24, height: 24)
                                .foregroundColor(.white)
                                .background(Color.black.cornerRadius(6))
                                .padding(8)
                        } else {
                            Circle()
                                .fill(Color.black.opacity(0.5))
                                .frame(width: 28, height: 28)
                                .overlay(
                                    LazyImage(url: URL(string: item.module.metadata.iconUrl)) { state in
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
                                .padding(8)
                        }
                    },
                    alignment: .topLeading
                )
            }
            .frame(width: 280, height: 157.03)
        }
        .contextMenu {
            Button(action: {
                markAsWatched()
            }) {
                Label("Mark as Watched", systemImage: "checkmark.circle")
            }
            Button(role: .destructive, action: {
                removeItem()
            }) {
                Label("Remove Item", systemImage: "trash")
            }
        }
        .onAppear {
            updateProgress()
        }
        .onChange(of: scenePhase) { newPhase in
            if newPhase == .active {
                updateProgress()
            }
        }
    }
    
    private func updateProgress() {
        let lastPlayed = UserDefaults.standard.double(forKey: "lastPlayedTime_\(item.fullUrl)")
        let totalTime  = UserDefaults.standard.double(forKey: "totalTime_\(item.fullUrl)")
        
        let ratio: Double
        if totalTime > 0 {
            ratio = min(max(lastPlayed / totalTime, 0), 1)
        } else {
            ratio = min(max(item.progress, 0), 1)
        }
        currentProgress = ratio
        
        if ratio >= 0.9 {
            removeItem()
        } else {
            var updated = item
            updated.progress = ratio
            ContinueWatchingManager.shared.save(item: updated)
        }
    }
}


struct RoundedCorner: Shape {
    var radius: CGFloat = .infinity
    var corners: UIRectCorner = .allCorners
    
    func path( in rect: CGRect) -> Path {
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
    
    func gradientOutline() -> some View {
        self.background(
            RoundedRectangle(cornerRadius: 15)
                .stroke(
                    LinearGradient(
                        gradient: Gradient(stops: [
                            .init(color: Color.accentColor.opacity(0.25), location: 0),
                            .init(color: Color.accentColor.opacity(0), location: 1)
                        ]),
                        startPoint: .top,
                        endPoint: .bottom
                    ),
                    lineWidth: 0.5
                )
        )
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
            .frame(height: 243)
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
                ZStack {
                    LazyImage(url: URL(string: item.imageUrl)) { state in
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
                                .aspectRatio(2/3, contentMode: .fit)
                                .redacted(reason: .placeholder)
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
                        Text(item.title)
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
                }
                .frame(width: 162, height: 243)
                .clipShape(RoundedRectangle(cornerRadius: 12))
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
