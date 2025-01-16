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
    
    private let columns = [
        GridItem(.adaptive(minimum: 150), spacing: 16)
    ]
    
    var body: some View {
        NavigationView {
            ScrollView {
                if libraryManager.bookmarks.isEmpty {
                    VStack(spacing: 8) {
                        Image(systemName: "magazine")
                            .font(.largeTitle)
                            .foregroundColor(.secondary)
                        Text("No Items saved")
                            .font(.headline)
                        Text("You can bookmark items to find them easily here.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding()
                    .frame(maxWidth: .infinity)
                } else {
                    LazyVGrid(columns: columns, spacing: 16) {
                        ForEach(libraryManager.bookmarks) { item in
                            if let module = moduleManager.modules.first(where: { $0.id.uuidString == item.moduleId }) {
                                NavigationLink(destination: MediaInfoView(title: item.title, imageUrl: item.imageUrl, href: item.href, module: module)) {
                                    VStack {
                                        ZStack(alignment: .bottomTrailing) {
                                            KFImage(URL(string: item.imageUrl))
                                                .resizable()
                                                .aspectRatio(2/3, contentMode: .fill)
                                                .cornerRadius(10)
                                                .frame(width: 150, height: 225)
                                            
                                            KFImage(URL(string: module.metadata.iconUrl))
                                                .resizable()
                                                .aspectRatio(contentMode: .fit)
                                                .frame(width: 35, height: 35)
                                                .clipShape(Circle())
                                                .padding(5)
                                        }
                                        
                                        Text(item.title)
                                            .font(.subheadline)
                                            .foregroundColor(.primary)
                                            .lineLimit(2)
                                            .multilineTextAlignment(.center)
                                            .padding(.horizontal, 8)
                                    }
                                }
                            }
                        }
                    }
                    .padding()
                }
            }
            .navigationTitle("Library")
            .navigationViewStyle(StackNavigationViewStyle())
        }
    }
}
