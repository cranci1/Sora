//
//  LibraryView.swift
//  Sora
//
//  Created by Francesco on 05/01/25.
//

import SwiftUI
import Kingfisher

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
            ScrollView {
                let columnsCount = determineColumns()
                
                VStack(alignment: .leading, spacing: 12) {
                    Text("Continue Watching")
                        .font(.title2)
                        .bold()
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
                    
                    Text("Bookmarks")
                        .font(.title2)
                        .bold()
                        .padding(.horizontal, 20)
                    
                    if libraryManager.bookmarks.isEmpty {
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
                    } else {
                        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: columnsCount), spacing: 12) {
                            ForEach(libraryManager.bookmarks) { item in
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
                                                    .frame(height: cellWidth * 3 / 2)
                                                    .frame(maxWidth: cellWidth)
                                                    .cornerRadius(10)
                                                    .clipped()
                                                    .overlay(
                                                        KFImage(URL(string: module.metadata.iconUrl))
                                                            .resizable()
                                                            .frame(width: 24, height: 24)
                                                            .cornerRadius(4)
                                                            .padding(4),
                                                        alignment: .topLeading
                                                    )
                                            }
                                            Text(item.title)
                                                .font(.subheadline)
                                                .foregroundColor(.primary)
                                                .lineLimit(1)
                                                .multilineTextAlignment(.leading)
                                        }
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
                        .padding(.horizontal, 20)
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
                        .onAppear {
                            updateOrientation()
                        }
                        .onReceive(NotificationCenter.default.publisher(for: UIDevice.orientationDidChangeNotification)) { _ in
                            updateOrientation()
                        }
                    }
                }
                .padding(.vertical, 20)
            }
            .navigationTitle("Library")
            .onAppear {
                fetchContinueWatching()
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
        VStack(alignment: .leading) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(Array(items.reversed())) { item in
                        ContinueWatchingCell(item: item, markAsWatched: {
                            markAsWatched(item)
                        }, removeItem: {
                            removeItem(item)
                        })
                    }
                }
                .padding(.horizontal, 20)
            }
            .frame(height: 190)
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
            VStack(alignment: .leading) {
                ZStack {
                    KFImage(URL(string: item.imageUrl.isEmpty ? "https://raw.githubusercontent.com/cranci1/Sora/refs/heads/main/assets/banner2.png" : item.imageUrl))
                        .placeholder {
                            RoundedRectangle(cornerRadius: 10)
                                .fill(Color.gray.opacity(0.3))
                                .frame(width: 240, height: 135)
                                .shimmering()
                        }
                        .setProcessor(RoundCornerImageProcessor(cornerRadius: 10))
                        .resizable()
                        .aspectRatio(16/9, contentMode: .fill)
                        .frame(width: 240, height: 135)
                        .cornerRadius(10)
                        .clipped()
                        .overlay(
                            KFImage(URL(string: item.module.metadata.iconUrl))
                                .resizable()
                                .frame(width: 24, height: 24)
                                .cornerRadius(4)
                                .padding(4),
                            alignment: .topLeading
                        )
                }
                .overlay(
                    ZStack {
                        Rectangle()
                            .fill(Color.black.opacity(0.3))
                            .blur(radius: 3)
                            .frame(height: 30)
                        
                        ProgressView(value: currentProgress)
                            .progressViewStyle(LinearProgressViewStyle(tint: .white))
                            .padding(.horizontal, 8)
                            .scaleEffect(x: 1, y: 1.5, anchor: .center)
                    },
                    alignment: .bottom
                )
                
                VStack(alignment: .leading) {
                    Text("Episode \(item.episodeNumber)")
                        .font(.caption)
                        .lineLimit(1)
                        .foregroundColor(.secondary)
                    
                    Text(item.mediaTitle)
                        .font(.caption)
                        .lineLimit(2)
                        .foregroundColor(.primary)
                        .multilineTextAlignment(.leading)
                }
            }
            .frame(width: 240, height: 170)
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
