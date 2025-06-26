//
//  AllReading.swift
//  Sora
//
//  Created by paul on 26/06/25.
//

import SwiftUI
import NukeUI

struct AllReadingView: View {
    @State private var continueReadingItems: [ContinueReadingItem] = []
    @State private var isRefreshing: Bool = false
    @Environment(\.scenePhase) private var scenePhase
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                if continueReadingItems.isEmpty {
                    emptyStateView
                } else {
                    LazyVGrid(columns: [
                        GridItem(.adaptive(minimum: 280), spacing: 16)
                    ], spacing: 16) {
                        ForEach(continueReadingItems) { item in
                            ContinueReadingListCell(item: item, 
                                                   markAsRead: {
                                markContinueReadingItemAsRead(item: item)
                            }, removeItem: {
                                removeContinueReadingItem(item: item)
                            })
                        }
                    }
                }
            }
            .padding(.horizontal)
            .padding(.top)
        }
        .navigationTitle("Continue Reading")
        .onAppear {
            fetchContinueReading()
        }
        .onChange(of: scenePhase) { newPhase in
            if newPhase == .active {
                fetchContinueReading()
            }
        }
        .refreshable {
            isRefreshing = true
            fetchContinueReading()
            isRefreshing = false
        }
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "book.closed")
                .font(.system(size: 50))
                .foregroundColor(.gray)
            
            Text("No Reading History")
                .font(.title2)
                .fontWeight(.bold)
            
            Text("Books you're reading will appear here")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 60)
    }
    
    private func fetchContinueReading() {
        continueReadingItems = ContinueReadingManager.shared.fetchItems()
    }
    
    private func markContinueReadingItemAsRead(item: ContinueReadingItem) {
        UserDefaults.standard.set(1.0, forKey: "readingProgress_\(item.href)")
        ContinueReadingManager.shared.updateProgress(for: item.href, progress: 1.0)
        fetchContinueReading()
    }
    
    private func removeContinueReadingItem(item: ContinueReadingItem) {
        ContinueReadingManager.shared.remove(item: item)
        fetchContinueReading()
    }
}

struct ContinueReadingListCell: View {
    let item: ContinueReadingItem
    var markAsRead: () -> Void
    var removeItem: () -> Void
    
    @Environment(\.colorScheme) private var colorScheme
    
    var body: some View {
        NavigationLink(destination: ReaderView(
            moduleId: item.moduleId,
            chapterHref: item.href,
            chapterTitle: item.chapterTitle,
            mediaTitle: item.mediaTitle
        )) {
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
                                Text("Chapter \(item.chapterNumber)")
                                    .font(.subheadline)
                                    .foregroundColor(.white.opacity(0.9))
                                
                                Spacer()
                                
                                Text("\(Int(item.progress * 100))% read")
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
                                Image(systemName: "book")
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: 14, height: 14)
                                    .foregroundColor(.white)
                            )
                            .padding(8)
                    },
                    alignment: .topLeading
                )
            }
            .frame(width: 280, height: 157.03)
        }
        .contextMenu {
            Button(action: {
                markAsRead()
            }) {
                Label("Mark as Read", systemImage: "checkmark.circle")
            }
            Button(role: .destructive, action: {
                removeItem()
            }) {
                Label("Remove Item", systemImage: "trash")
            }
        }
    }
} 