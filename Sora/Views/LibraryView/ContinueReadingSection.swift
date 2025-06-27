//
//  ContinueReadingSection.swift
//  Sora
//
//  Created by paul on 26/06/25.
//

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
    @State private var imageLoadError: Bool = false
    
    private var imageURL: URL {
        print("Processing image URL in ContinueReadingCell: \(item.imageUrl)")
        
        if !item.imageUrl.isEmpty {
            if let url = URL(string: item.imageUrl) {
                print("Valid direct URL: \(url)")
                return url
            }
            
            if let encodedUrlString = item.imageUrl.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
               let url = URL(string: encodedUrlString) {
                print("Using encoded URL: \(encodedUrlString)")
                return url
            }
            
            if item.imageUrl.hasPrefix("http://") {
                let httpsUrl = "https://" + item.imageUrl.dropFirst(7)
                if let url = URL(string: httpsUrl) {
                    print("Using https URL: \(httpsUrl)")
                    return url
                }
            }
        }
        
        print("Using fallback URL")
        return URL(string: "https://raw.githubusercontent.com/cranci1/Sora/refs/heads/main/assets/banner2.png")!
    }
    
    var body: some View {
        NavigationLink(destination: ReaderView(
            moduleId: item.moduleId,
            chapterHref: item.href,
            chapterTitle: item.chapterTitle,
            chapters: [],
            mediaTitle: item.mediaTitle,
            chapterNumber: item.chapterNumber
        )) {
            ZStack {
                LazyImage(url: imageURL) { state in
                    if let image = state.imageContainer?.image {
                        Image(uiImage: image)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: 280, height: 157.03)
                            .blur(radius: 3)
                            .opacity(0.7)
                    } else {
                        Rectangle()
                            .fill(Color.gray.opacity(0.3))
                            .frame(width: 280, height: 157.03)
                    }
                }
                .onAppear {
                    print("Background image loading: \(imageURL)")
                }
                
                Rectangle()
                    .fill(LinearGradient(
                        gradient: Gradient(colors: [Color.black.opacity(0.7), Color.black.opacity(0.4)]),
                        startPoint: .leading,
                        endPoint: .trailing
                    ))
                    .frame(width: 280, height: 157.03)
                
                HStack(spacing: 0) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("\(Int(item.progress * 100))%")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundColor(.white)
                            .padding(.vertical, 4)
                            .padding(.horizontal, 8)
                            .background(Color.black.opacity(0.6))
                            .cornerRadius(4)
                        
                        Spacer()
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Chapter \(item.chapterNumber)")
                                .font(.caption)
                                .foregroundColor(.white.opacity(0.9))
                            
                            Text(item.mediaTitle)
                                .font(.headline)
                                .fontWeight(.bold)
                                .foregroundColor(.white)
                                .lineLimit(2)
                        }
                    }
                    .padding(12)
                    .frame(width: 170, alignment: .leading)
                    
                    LazyImage(url: imageURL) { state in
                        if let image = state.imageContainer?.image {
                            Image(uiImage: image)
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(width: 110, height: 157.03)
                                .clipped()
                        } else {
                            Rectangle()
                                .fill(Color.gray.opacity(0.3))
                                .frame(width: 110, height: 157.03)
                        }
                    }
                    .onAppear {
                        print("Right image loading: \(imageURL)")
                    }
                    .onDisappear {
                        print("Right image disappeared")
                    }
                    .frame(width: 110, height: 157.03)
                }
            }
            .frame(width: 280, height: 157.03)
            .cornerRadius(10)
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(Color.gray.opacity(0.3), lineWidth: 0.5)
            )
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
        .onAppear {
            print("ContinueReadingCell appeared for: \(item.mediaTitle)")
            print("Image URL: \(item.imageUrl)")
            print("Chapter: \(item.chapterNumber)")
            print("Progress: \(item.progress)")
        }
    }
}
