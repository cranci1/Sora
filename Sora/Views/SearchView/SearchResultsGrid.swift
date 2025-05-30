//
//  SearchResultsGrid.swift
//  Sora
//
//  Created by paul on 28/05/25.
//

import SwiftUI
import Kingfisher

struct SearchResultsGrid: View {
    let items: [SearchItem]
    let columns: [GridItem]
    let selectedModule: ScrapingModule
    
    var body: some View {
        LazyVGrid(columns: columns, spacing: 16) {
            ForEach(items) { item in
                NavigationLink(destination: MediaInfoView(title: item.title, imageUrl: item.imageUrl, href: item.href, module: selectedModule)) {
                    ZStack {
                        KFImage(URL(string: item.imageUrl))
                            .resizable()
                            .aspectRatio(0.72, contentMode: .fill)
                            .frame(width: 162, height: 243)
                            .cornerRadius(12)
                            .clipped()
                        
                        VStack {
                                Spacer()
                                HStack {
                                    Text(item.title)
                                        .lineLimit(2)
                                        .foregroundColor(.white)
                                        .multilineTextAlignment(.leading)
                                    Spacer()
                                }
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
                            .frame(width: 162)
                    }
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .padding(4)
                }
            }
        }
        .padding(.top)
        .padding()
    }
} 
