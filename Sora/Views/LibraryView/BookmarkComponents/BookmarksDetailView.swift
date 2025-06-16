//
//  MediaInfoView.swift
//  Sora
//
//  Created by paul on 28/05/25.
//

import UIKit
import SwiftUI

struct BookmarksDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var libraryManager: LibraryManager
    @EnvironmentObject private var moduleManager: ModuleManager
    
    @Binding var bookmarks: [LibraryItem]
    @State private var sortOption: SortOption = .dateAdded
    @State private var searchText: String = ""
    @State private var isSearchActive: Bool = false
    
    enum SortOption: String, CaseIterable {
        case dateAdded = "Date Added"
        case title = "Title"
        case source = "Source"
    }
    
    var filteredAndSortedBookmarks: [LibraryItem] {
        let filtered = searchText.isEmpty ? bookmarks : bookmarks.filter { item in
            item.title.localizedCaseInsensitiveContains(searchText) ||
            item.moduleName.localizedCaseInsensitiveContains(searchText)
        }
        switch sortOption {
        case .dateAdded:
            return filtered
        case .title:
            return filtered.sorted { $0.title.lowercased() < $1.title.lowercased() }
        case .source:
            return filtered.sorted { item1, item2 in
                let module1 = moduleManager.modules.first { $0.id.uuidString == item1.moduleId }
                let module2 = moduleManager.modules.first { $0.id.uuidString == item2.moduleId }
                return (module1?.metadata.sourceName ?? "") < (module2?.metadata.sourceName ?? "")
            }
        }
    }
    
    var body: some View {
        VStack(alignment: .leading) {
            HStack(spacing: 8) {
                Button(action: { dismiss() }) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 24))
                        .foregroundColor(.primary)
                }
                Button(action: { dismiss() }) {
                    Text("All Bookmarks")
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
                        TextField("Search bookmarks...", text: $searchText)
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
            BookmarksDetailGrid(
                bookmarks: filteredAndSortedBookmarks,
                moduleManager: moduleManager
            )
        }
        .navigationBarBackButtonHidden(true)
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
               let window = windowScene.windows.first,
               let navigationController = window.rootViewController?.children.first as? UINavigationController {
                navigationController.interactivePopGestureRecognizer?.isEnabled = true
                navigationController.interactivePopGestureRecognizer?.delegate = nil
            }
        }
    }
}

private struct SortMenu: View {
    @Binding var sortOption: BookmarksDetailView.SortOption
    var body: some View {
        Menu {
            ForEach(BookmarksDetailView.SortOption.allCases, id: \.self) { option in
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
}

private struct BookmarksDetailGrid: View {
    let bookmarks: [LibraryItem]
    let moduleManager: ModuleManager
    private let columns = [GridItem(.adaptive(minimum: 150))]
    var body: some View {
        ScrollView(showsIndicators: false) {
            LazyVGrid(columns: columns, spacing: 16) {
                ForEach(bookmarks) { bookmark in
                    BookmarksDetailGridCell(bookmark: bookmark, moduleManager: moduleManager)
                }
            }
            .padding(.top)
            .padding()
            .scrollViewBottomPadding()
        }
    }
}

private struct BookmarksDetailGridCell: View {
    let bookmark: LibraryItem
    let moduleManager: ModuleManager
    var body: some View {
        if let module = moduleManager.modules.first(where: { $0.id.uuidString == bookmark.moduleId }) {
            NavigationLink(destination: MediaInfoView(
                title: bookmark.title,
                imageUrl: bookmark.imageUrl,
                href: bookmark.href,
                module: module
            )) {
                BookmarkCell(bookmark: bookmark)
            }
        }
    }
} 
