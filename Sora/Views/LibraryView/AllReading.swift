import SwiftUI
import NukeUI

struct AllReadingView: View {
    @State private var continueReadingItems: [ContinueReadingItem] = []
    @State private var isRefreshing: Bool = false
    @Environment(\.scenePhase) private var scenePhase
    
    var body: some View {
        ScrollView {
            LazyVStack(spacing: 16) {
                if continueReadingItems.isEmpty {
                    emptyStateView
                } else {
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
    
    var body: some View {
        NavigationLink(destination: ReaderView(
            moduleId: item.moduleId,
            chapterHref: item.href,
            chapterTitle: item.chapterTitle
        )) {
            HStack(alignment: .center, spacing: 12) {
                // Cover image
                LazyImage(url: URL(string: item.imageUrl.isEmpty ? "https://raw.githubusercontent.com/cranci1/Sora/refs/heads/main/assets/banner2.png" : item.imageUrl)) { state in
                    if let uiImage = state.imageContainer?.image {
                        Image(uiImage: uiImage)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: 80, height: 120)
                            .cornerRadius(8)
                    } else {
                        Rectangle()
                            .fill(Color.gray.opacity(0.3))
                            .frame(width: 80, height: 120)
                            .cornerRadius(8)
                    }
                }
                
                // Content
                VStack(alignment: .leading, spacing: 4) {
                    Text(item.mediaTitle)
                        .font(.headline)
                        .lineLimit(2)
                    
                    Text(item.chapterTitle)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                    
                    HStack {
                        Text("Chapter \(item.chapterNumber)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Spacer()
                        
                        if item.progress >= 0.98 {
                            HStack(spacing: 2) {
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.system(size: 10))
                                    .foregroundColor(.green)
                                Text("Completed")
                                    .foregroundColor(.green)
                            }
                            .font(.caption)
                        } else {
                            Text("\(Int(item.progress * 100))% read")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    // Progress bar
                    ProgressView(value: item.progress)
                        .progressViewStyle(LinearProgressViewStyle())
                        .frame(height: 4)
                }
                
                Spacer()
            }
            .padding(12)
            .background(Color.gray.opacity(0.1))
            .cornerRadius(12)
        }
        .buttonStyle(PlainButtonStyle())
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