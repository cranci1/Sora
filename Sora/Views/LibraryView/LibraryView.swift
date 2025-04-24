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
    
    @AppStorage("mediaColumnsPortrait") private var mediaColumnsPortrait: Int = 3
    @AppStorage("mediaColumnsLandscape") private var mediaColumnsLandscape: Int = 5
    
    @Environment(\.verticalSizeClass) var verticalSizeClass
    @Environment(\.colorScheme) private var colorScheme
    
    @State private var continueWatchingItems: [ContinueWatchingItem] = []
    @State private var isLandscape: Bool = UIDevice.current.orientation.isLandscape
    
    private let columns = [
        GridItem(.adaptive(minimum: 120), spacing: 10)
    ]
    
    private var columnsCount: Int {
        /* Fixed to 3 for the time being
        if UIDevice.current.userInterfaceIdiom == .pad {
            let isLandscape = UIScreen.main.bounds.width > UIScreen.main.bounds.height
            return isLandscape ? mediaColumnsLandscape : mediaColumnsPortrait
        } else {
            return verticalSizeClass == .compact ? mediaColumnsLandscape : mediaColumnsPortrait
        }
         */
        if UIDevice.current.userInterfaceIdiom == .pad {
            return 4
        }
        else {
            return 3
        }
    }
    
    private var cellWidth: CGFloat {
        let keyWindow = UIApplication.shared.connectedScenes
            .compactMap { ($0 as? UIWindowScene)?.windows.first(where: { $0.isKeyWindow }) }
            .first
        let safeAreaInsets = keyWindow?.safeAreaInsets ?? .zero
        let safeWidth = UIScreen.main.bounds.width - safeAreaInsets.left - safeAreaInsets.right
        let totalSpacing: CGFloat = 14 * CGFloat(columnsCount)
        let availableWidth = safeWidth - totalSpacing
        return (availableWidth / CGFloat(columnsCount)) * 2.5
    }
    
    var body: some View {
        NavigationView {
            ScrollView {
                let columnsCount = determineColumns()
                
                VStack(alignment: .leading, spacing: 20) {
                    // Continue Watching Section
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Continue Watching")
                            .font(.title3)
                            .bold()
                            .padding(.horizontal, 16)
                        Group {
                            if continueWatchingItems.isEmpty {
                                VStack(spacing: 6) {
                                    Image(systemName: "play.circle")
                                        .font(.title)
                                        .foregroundColor(.secondary)
                                    Text("No items to continue watching.")
                                        .font(.subheadline)
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
                        }
                        .padding(.vertical, 10)
                        .padding(.horizontal, 4)
                        .background(
                            Group {
                                Color(.systemBackground)
                                    .opacity(0.8)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 14)
                                            .stroke(Color.secondary.opacity(0.5), lineWidth: 0.5)
                                    )
                                    .blur(radius: 0.5)
                                    .clipShape(RoundedRectangle(cornerRadius: 14))
                            }
                        )
                        .shadow(color: colorScheme == .dark ? Color(.label).opacity(0.1) : Color.black.opacity(0.1), radius: 8)
                        .padding(.horizontal, 16)
                    }
                    
                    // Bookmarks Section
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Bookmarks")
                            .font(.title3)
                            .bold()
                            .padding(.horizontal, 16)
                            
                        GeometryReader { geometry in
                            VStack {
                                if libraryManager.bookmarks.isEmpty {
                                    VStack(spacing: 6) {
                                        Image(systemName: "magazine")
                                            .font(.title)
                                            .foregroundColor(.secondary)
                                        Text("You have no items saved.")
                                            .font(.subheadline)
                                        Text("Bookmark items for easier access later.")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                    .padding()
                                    .frame(maxWidth: .infinity)
                                } else {
                                    ScrollView(.horizontal, showsIndicators: false) {
                                        LazyHGrid(rows: Array(repeating: GridItem(.flexible(), spacing: 16), count: 1), spacing: 16) {
                                            ForEach(libraryManager.bookmarks) { item in
                                                if let module = moduleManager.modules.first(where: { $0.id.uuidString == item.moduleId }) {
                                                    NavigationLink(destination: MediaInfoView(title: item.title, imageUrl: item.imageUrl, href: item.href, module: module)) {
                                                        ZStack(alignment: .bottom) {
                                                            KFImage(URL(string: item.imageUrl))
                                                                .placeholder {
                                                                    RoundedRectangle(cornerRadius: 8)
                                                                        .fill(Color.gray.opacity(0.3))
                                                                        .aspectRatio(2/3, contentMode: .fit)
                                                                        .shimmering()
                                                                }
                                                                .resizable()
                                                                .aspectRatio(contentMode: .fill)
                                                                .frame(width: cellWidth * 0.6, height: (cellWidth * 0.6) * 3 / 2)
                                                                .cornerRadius(8)
                                                                .clipped()
                                                                .overlay(
                                                                    KFImage(URL(string: module.metadata.iconUrl))
                                                                        .resizable()
                                                                        .frame(width: 20, height: 20)
                                                                        .cornerRadius(3)
                                                                        .padding(3),
                                                                    alignment: .topLeading
                                                                )
                                                            
                                                            Text(item.title)
                                                                .font(.subheadline.weight(.semibold))
                                                                .foregroundColor(.white)
                                                                .padding(8)
                                                                .frame(maxWidth: .infinity, alignment: .leading)
                                                                .background(
                                                                    LinearGradient(
                                                                        gradient: Gradient(colors: [Color.black.opacity(0.6), Color.black.opacity(0.0)]),
                                                                        startPoint: .bottom,
                                                                        endPoint: .top
                                                                    )
                                                                )
                                                        }
                                                        .frame(width: cellWidth * 0.6, height: (cellWidth * 0.6) * 3 / 2)
                                                        .background(.ultraThinMaterial)
                                                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                                                        .overlay(
                                                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                                                .stroke(Color.secondary.opacity(0.3), lineWidth: 1)
                                                        )
                                                        .shadow(color: Color.black.opacity(0.1), radius: 4, x: 0, y: 2)
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
                                        .padding(.horizontal, 16)
                                        .padding(.vertical, 6)
                                    }
                                    .clipShape(RoundedRectangle(cornerRadius: 8))
                                }
                            }
                            .frame(height: isLandscape ? geometry.size.height * 0.9 : geometry.size.height * 0.75) 
                            .background(
                                Group {
                                    Color(.systemBackground)
                                        .opacity(0.8)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 14)
                                                .stroke(Color.secondary.opacity(0.5), lineWidth: 0.5)
                                        )
                                        .blur(radius: 0.5)
                                        .clipShape(RoundedRectangle(cornerRadius: 14))
                                }
                            )
                            .shadow(color: colorScheme == .dark ? Color(.label).opacity(0.1) : Color.black.opacity(0.1), radius: 8)
                            .padding(.bottom, 70)
                        }
                        .frame(height: isLandscape ? UIScreen.main.bounds.height * 0.6 : UIScreen.main.bounds.height * 0.5) // Adjusted frame height for landscape
                        .padding(.horizontal, 16)
                    }

                }
                .navigationTitle("Library")
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
        /* Fixed at 3 for the time being
        if UIDevice.current.userInterfaceIdiom == .pad {
            return isLandscape ? mediaColumnsLandscape : mediaColumnsPortrait
        } else {
            return verticalSizeClass == .compact ? mediaColumnsLandscape : mediaColumnsPortrait
        }*/
        if UIDevice.current.userInterfaceIdiom == .pad {
            return 4
        }
        else {
            return 3
        }
    }
}

struct ContinueWatchingSection: View {
    @Binding var items: [ContinueWatchingItem]
    var markAsWatched: (ContinueWatchingItem) -> Void
    var removeItem: (ContinueWatchingItem) -> Void
    @Environment(\.colorScheme) private var colorScheme
    
    var body: some View {
        VStack(alignment: .leading) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(Array(items.reversed())) { item in
                        ContinueWatchingCell(item: item, markAsWatched: {
                            markAsWatched(item)
                        }, removeItem: {
                            removeItem(item)
                        })
                    }
                }
                .padding(.horizontal, 12)
            }
            .frame(height: 170)
        }
    }
}

struct ContinueWatchingCell: View {
    let item: ContinueWatchingItem
    var markAsWatched: () -> Void
    var removeItem: () -> Void
    @Environment(\.colorScheme) private var colorScheme
    
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
                    episodeImageUrl: item.imageUrl
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
                                .frame(width: 220, height: 120)
                                .shimmering()
                        }
                        .setProcessor(RoundCornerImageProcessor(cornerRadius: 10))
                        .resizable()
                        .aspectRatio(16/9, contentMode: .fill)
                        .frame(width: 220, height: 120)
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
                            .frame(height: 24)
                        
                        ProgressView(value: currentProgress)
                            .progressViewStyle(LinearProgressViewStyle(tint: .white))
                            .padding(.horizontal, 8)
                            .scaleEffect(x: 1, y: 1.2, anchor: .center)
                    },
                    alignment: .bottom
                )
                .shadow(radius: 5)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("Episode \(item.episodeNumber)")
                        .font(.caption2)
                        .lineLimit(1)
                        .foregroundColor(.secondary)
                    
                    Text(item.mediaTitle)
                        .font(.caption)
                        .lineLimit(2)
                        .foregroundColor(.primary)
                        .multilineTextAlignment(.leading)
                }
                .padding(.horizontal, 8)
                .padding(.top, -3)
            }
            .frame(width: 220, height: 160)
            .background(
                Group {
                    Color(.systemBackground)
                        .opacity(0.6)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color.secondary.opacity(0.2), lineWidth: 0.5)
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
            )
            .shadow(color: colorScheme == .dark ? Color(.label).opacity(0.1) : Color.black.opacity(0.1), radius: 3)
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
            currentProgress = lastPlayedTime / totalTime
        } else {
            currentProgress = item.progress
        }
    }
}
