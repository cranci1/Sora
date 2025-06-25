import SwiftUI
import NukeUI

struct ContinueReadingSection: View {
    @Binding var items: [ContinueReadingItem]
    var markAsRead: (ContinueReadingItem) -> Void
    var removeItem: (ContinueReadingItem) -> Void
    
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(Array(items.prefix(5))) { item in
                    ContinueReadingCell(item: item, markAsRead: {
                        markAsRead(item)
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

struct ContinueReadingCell: View {
    let item: ContinueReadingItem
    var markAsRead: () -> Void
    var removeItem: () -> Void
    
    @Environment(\.colorScheme) private var colorScheme
    
    var body: some View {
        NavigationLink(destination: ReaderView(
            moduleId: item.moduleId,
            chapterHref: item.href,
            chapterTitle: item.chapterTitle
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
                                
                                if item.progress >= 0.98 {
                                    HStack(spacing: 2) {
                                        Image(systemName: "checkmark.circle.fill")
                                            .font(.system(size: 10))
                                        Text("Completed")
                                    }
                                    .font(.caption)
                                    .foregroundColor(.green.opacity(0.9))
                                } else {
                                    Text("\(Int(item.progress * 100))% read")
                                        .font(.caption)
                                        .foregroundColor(.white.opacity(0.9))
                                }
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