//
//  AllBookmarks.swift
//  Sulfur
//
//  Created by paul on 24/05/2025.
//

import UIKit
import NukeUI
import SwiftUI

extension View {
    func circularGradientOutline() -> some View {
        self.background(
            Circle()
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

struct AllWatchingView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var moduleManager: ModuleManager
    
    @State private var continueWatchingItems: [ContinueWatchingItem] = []
    @State private var sortOption: SortOption = .dateAdded
    
    enum SortOption: String, CaseIterable {
        case dateAdded = "Recently Added"
        case title = "Series Title"
        case source = "Content Source"
        case progress = "Watch Progress"
    }
    
    var sortedItems: [ContinueWatchingItem] {
        switch sortOption {
        case .dateAdded:
            return continueWatchingItems.reversed() 
        case .title:
            return continueWatchingItems.sorted { $0.mediaTitle.lowercased() < $1.mediaTitle.lowercased() }
        case .source:
            return continueWatchingItems.sorted { $0.module.metadata.sourceName < $1.module.metadata.sourceName }
        case .progress:
            return continueWatchingItems.sorted { $0.progress > $1.progress }
        }
    }
    
    var body: some View {
        VStack(alignment: .leading) {
            HStack {
                Button(action: {
                    dismiss()
                }) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 24))
                        .foregroundColor(.primary)
                }
                
                Button(action: {
                    dismiss()
                }) {
                    Text("All Watching")
                        .font(.title3)
                        .fontWeight(.bold)
                        .foregroundColor(.primary)
                }
                
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
                        .frame(width: 24, height: 24)
                        .foregroundColor(.accentColor)
                        .padding(6)
                        .background(Color.gray.opacity(0.2))
                        .clipShape(Circle())
                        .circularGradientOutline()
                }
            }
            .padding(.horizontal)
            .padding(.top)
            
            ScrollView(showsIndicators: false) {
                LazyVStack(spacing: 12) {
                    ForEach(sortedItems) { item in
                        FullWidthContinueWatchingCell(
                            item: item,
                            markAsWatched: {
                                markAsWatched(item: item)
                            },
                            removeItem: {
                                removeItem(item: item)
                            }
                        )
                    }
                }
                .padding(.top)
                .padding()
                .scrollViewBottomPadding()
            }
        }
        .navigationBarBackButtonHidden(true)
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            loadContinueWatchingItems()
            
            // Enable swipe back gesture
            if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
               let window = windowScene.windows.first,
               let navigationController = window.rootViewController?.children.first as? UINavigationController {
                navigationController.interactivePopGestureRecognizer?.isEnabled = true
                navigationController.interactivePopGestureRecognizer?.delegate = nil
            }
        }
    }
    
    private func loadContinueWatchingItems() {
        continueWatchingItems = ContinueWatchingManager.shared.fetchItems()
    }
    
    private func markAsWatched(item: ContinueWatchingItem) {
        let key = "lastPlayedTime_\(item.fullUrl)"
        let totalKey = "totalTime_\(item.fullUrl)"
        UserDefaults.standard.set(99999999.0, forKey: key)
        UserDefaults.standard.set(99999999.0, forKey: totalKey)
        ContinueWatchingManager.shared.remove(item: item)
        loadContinueWatchingItems()
    }
    
    private func removeItem(item: ContinueWatchingItem) {
        ContinueWatchingManager.shared.remove(item: item)
        loadContinueWatchingItems()
    }
}

struct FullWidthContinueWatchingCell: View {
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
            GeometryReader { geometry in
                ZStack(alignment: .bottomLeading) {
                    LazyImage(url: URL(string: item.imageUrl.isEmpty ? "https://raw.githubusercontent.com/cranci1/Sora/refs/heads/main/assets/banner2.png" : item.imageUrl)) { state in
                        if let uiImage = state.imageContainer?.image {
                            Image(uiImage: uiImage)
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(width: geometry.size.width, height: 157.03)
                                .cornerRadius(10)
                                .clipped()
                        } else {
                            RoundedRectangle(cornerRadius: 10)
                                .fill(Color.gray.opacity(0.3))
                                .frame(height: 157.03)
                                .shimmering()
                        }
                    }
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
                        }
                            .padding(8),
                        alignment: .topLeading
                    )
                }
            }
            .frame(height: 157.03)
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
