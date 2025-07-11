//
//  BookmarkGridItemView.swift
//  Sora
//
//  Created by paul on 28/05/25.
//

import SwiftUI
import NukeUI

struct BookmarkGridItemView: View {
    let item: LibraryItem
    let module: Module
    
    var isNovel: Bool {
        module.metadata.novel ?? false
    }
    
    var body: some View {
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
                ZStack(alignment: .bottomTrailing) {
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
                    ZStack {
                        Circle()
                            .fill(Color.gray.opacity(0.8))
                            .shadow(color: .accentColor.opacity(0.2), radius: 2)
                            .frame(width: 20, height: 20)
                        Image(systemName: isNovel ? "book.fill" : "tv.fill")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 10, height: 10)
                            .foregroundColor(.white)
                    }
                    .circularGradientOutline()
                    .offset(x: 6, y: 6)
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
}
 
