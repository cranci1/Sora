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
    @State private var searchText: String = ""
    @State private var isSearchActive: Bool = false
    @State private var isSelecting: Bool = false
    @State private var selectedItems: Set<ContinueWatchingItem.ID> = []
    
    enum SortOption: String, CaseIterable {
        case dateAdded = "Recently Added"
        case title = "Series Title"
        case source = "Content Source"
        case progress = "Watch Progress"
    }
    
    var filteredAndSortedItems: [ContinueWatchingItem] {
        let filtered = searchText.isEmpty ? continueWatchingItems : continueWatchingItems.filter { item in
            item.mediaTitle.localizedCaseInsensitiveContains(searchText) ||
            item.module.metadata.sourceName.localizedCaseInsensitiveContains(searchText)
        }
        switch sortOption {
        case .dateAdded:
            return filtered.reversed()
        case .title:
            return filtered.sorted { $0.mediaTitle.lowercased() < $1.mediaTitle.lowercased() }
        case .source:
            return filtered.sorted { $0.module.metadata.sourceName < $1.module.metadata.sourceName }
        case .progress:
            return filtered.sorted { $0.progress > $1.progress }
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
                
                HStack(spacing: 16) {
                    Button(action: {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            isSearchActive.toggle()
                        }
                        if !isSearchActive {
                            searchText = ""
                        }
                    }) {
                        Image(systemName: isSearchActive ? "xmark.circle.fill" : "magnifyingglass")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 18, height: 18)
                            .foregroundColor(.accentColor)
                            .padding(10)
                            .background(
                                Circle()
                                    .fill(Color.gray.opacity(0.2))
                                    .shadow(color: .accentColor.opacity(0.2), radius: 2)
                            )
                            .circularGradientOutline()
                    }
                    Menu {
                        ForEach(SortOption.allCases, id: \.self) { option in
                            Button {
                                sortOption = option
                            } label: {
                                HStack {
                                    Text(NSLocalizedString(option.rawValue, comment: ""))
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
                            .scaledToFit()
                            .frame(width: 18, height: 18)
                            .foregroundColor(.accentColor)
                            .padding(10)
                            .background(
                                Circle()
                                    .fill(Color.gray.opacity(0.2))
                                    .shadow(color: .accentColor.opacity(0.2), radius: 2)
                            )
                            .circularGradientOutline()
                    }
                    Button(action: {
                        if isSelecting {
                            // If trash icon tapped
                            if !selectedItems.isEmpty {
                                for id in selectedItems {
                                    if let item = continueWatchingItems.first(where: { $0.id == id }) {
                                        ContinueWatchingManager.shared.remove(item: item)
                                    }
                                }
                                selectedItems.removeAll()
                                loadContinueWatchingItems()
                            }
                            isSelecting = false
                        } else {
                            isSelecting = true
                        }
                    }) {
                        Image(systemName: isSelecting ? "trash" : "checkmark.circle")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 18, height: 18)
                            .foregroundColor(isSelecting ? .red : .accentColor)
                            .padding(10)
                            .background(
                                Circle()
                                    .fill(Color.gray.opacity(0.2))
                                    .shadow(color: .accentColor.opacity(0.2), radius: 2)
                            )
                            .circularGradientOutline()
                    }
                }
            }
            .padding(.horizontal)
            .padding(.top)
            
            if isSearchActive {
                HStack(spacing: 12) {
                    HStack(spacing: 12) {
                        Image(systemName: "magnifyingglass")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 18, height: 18)
                            .foregroundColor(.secondary)
                        TextField("Search watching...", text: $searchText)
                            .textFieldStyle(PlainTextFieldStyle())
                            .foregroundColor(.primary)
                        if !searchText.isEmpty {
                            Button(action: {
                                searchText = ""
                            }) {
                                Image(systemName: "xmark.circle.fill")
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: 18, height: 18)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(.ultraThinMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .strokeBorder(
                                LinearGradient(
                                    gradient: Gradient(stops: [
                                        .init(color: Color.accentColor.opacity(0.25), location: 0),
                                        .init(color: Color.accentColor.opacity(0), location: 1)
                                    ]),
                                    startPoint: .top,
                                    endPoint: .bottom
                                ),
                                lineWidth: 1.5
                            )
                    )
                }
                .padding(.horizontal)
                .padding(.bottom, 8)
                .transition(.asymmetric(
                    insertion: .move(edge: .top).combined(with: .opacity),
                    removal: .move(edge: .top).combined(with: .opacity)
                ))
            }
            
            ScrollView(showsIndicators: false) {
                LazyVStack(spacing: 12) {
                    ForEach(filteredAndSortedItems) { item in
                        FullWidthContinueWatchingCell(
                            item: item,
                            markAsWatched: {
                                markAsWatched(item: item)
                            },
                            removeItem: {
                                removeItem(item: item)
                            },
                            isSelecting: isSelecting,
                            selectedItems: $selectedItems
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
        
        DispatchQueue.main.async {
            loadContinueWatchingItems()
        }
    }
    
    private func removeItem(item: ContinueWatchingItem) {
        ContinueWatchingManager.shared.remove(item: item)
        DispatchQueue.main.async {
            loadContinueWatchingItems()
        }
    }
}

@MainActor
struct FullWidthContinueWatchingCell: View {
    let item: ContinueWatchingItem
    var markAsWatched: () -> Void
    var removeItem: () -> Void
    var isSelecting: Bool
    var selectedItems: Binding<Set<ContinueWatchingItem.ID>>
    
    @State private var currentProgress: Double = 0.0
    
    var isSelected: Bool {
        selectedItems.wrappedValue.contains(item.id)
    }
    
    var body: some View {
        Group {
            if isSelecting {
                Button(action: {
                    if isSelected {
                        selectedItems.wrappedValue.remove(item.id)
                    } else {
                        selectedItems.wrappedValue.insert(item.id)
                    }
                }) {
                    ZStack(alignment: .topTrailing) {
                        cellContent
                        if isSelected {
                            Image(systemName: "checkmark.circle.fill")
                                .resizable()
                                .frame(width: 32, height: 32)
                                .foregroundColor(.black)
                                .background(Color.white.clipShape(Circle()).opacity(0.8))
                                .offset(x: -8, y: 8)
                        }
                    }
                }
            } else {
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
                            episodeTitle: item.episodeTitle ?? "",
                            seasonNumber: item.seasonNumber ?? 1,
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
                    cellContent
                }
            }
        }
        .contextMenu {
            Button(action: { markAsWatched() }) {
                Label("Mark as Watched", systemImage: "checkmark.circle")
            }
            Button(role: .destructive, action: { removeItem() }) {
                Label("Remove from Continue Watching", systemImage: "trash")
            }
        }
        .onAppear {
            updateProgress()
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)) { _ in
            updateProgress()
        }
    }
    
    private var cellContent: some View {
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
                                Text(episodeLabel(for: item))
                                    .font(.subheadline)
                                    .foregroundColor(.white.opacity(0.9))
                                    .lineLimit(2)
                                    .truncationMode(.tail)
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

private func episodeLabel(for item: ContinueWatchingItem) -> String {
    let hasTitle = !(item.episodeTitle?.isEmpty ?? true)
    let isSingleSeason = (item.seasonNumber ?? 1) <= 1
    let episodePart = "E\(item.episodeNumber)"
    let seasonPart = isSingleSeason ? "" : "S\(item.seasonNumber ?? 1)"
    let colon = hasTitle ? ":" : ""
    let title = item.episodeTitle ?? ""
    let main = [seasonPart, episodePart].filter { !$0.isEmpty }.joined()
    return hasTitle ? "\(main)\(colon) \(title)" : main
} 
