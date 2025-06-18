//
//  AllBookmarks.swift
//  Sulfur
//
//  Created by paul on 29/04/2025.
//

import UIKit
import NukeUI
import SwiftUI

extension View {
    func circularGradientOutlineTwo() -> some View {
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

struct AllBookmarks: View {
    @EnvironmentObject var libraryManager: LibraryManager
    @EnvironmentObject var moduleManager: ModuleManager
    @State private var searchText: String = ""
    @State private var isSearchActive: Bool = false
    @State private var sortOption: SortOption = .title
    @State private var isSelecting: Bool = false
    @State private var selectedBookmarks: Set<LibraryItem.ID> = []
    
    enum SortOption: String, CaseIterable {
        case title = "Title"
        case dateAdded = "Date Added"
        case source = "Source"
    }
    
    var filteredAndSortedBookmarks: [LibraryItem] {
        let filtered = searchText.isEmpty ? libraryManager.bookmarks : libraryManager.bookmarks.filter { item in
            item.title.localizedCaseInsensitiveContains(searchText) ||
            item.moduleName.localizedCaseInsensitiveContains(searchText)
        }
        switch sortOption {
        case .title:
            return filtered.sorted { $0.title.lowercased() < $1.title.lowercased() }
        case .dateAdded:
            return filtered
        case .source:
            return filtered.sorted { $0.moduleName < $1.moduleName }
        }
    }
    
    var body: some View {
        VStack(alignment: .leading) {
            HStack {
                Button(action: { }) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 24))
                        .foregroundColor(.primary)
                }
                Button(action: { }) {
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
                            .circularGradientOutlineTwo()
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
                            .circularGradientOutlineTwo()
                    }
                    Button(action: {
                        if isSelecting {
                            if !selectedBookmarks.isEmpty {
                                for id in selectedBookmarks {
                                    if let item = libraryManager.bookmarks.first(where: { $0.id == id }) {
                                        libraryManager.removeBookmark(item: item)
                                    }
                                }
                                selectedBookmarks.removeAll()
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
                            .circularGradientOutlineTwo()
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
            BookmarkGridView(
                bookmarks: filteredAndSortedBookmarks,
                moduleManager: moduleManager,
                isSelecting: isSelecting,
                selectedBookmarks: $selectedBookmarks
            )
            .withGridPadding()
            Spacer()
        }
        .navigationBarBackButtonHidden(true)
        .navigationBarTitleDisplayMode(.inline)
        .onAppear(perform: setupNavigationController)
    }
    
    private func setupNavigationController() {
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let window = windowScene.windows.first,
           let navigationController = window.rootViewController?.children.first as? UINavigationController {
            navigationController.interactivePopGestureRecognizer?.isEnabled = true
            navigationController.interactivePopGestureRecognizer?.delegate = nil
        }
    }
}

struct BookmarkCell: View {
    let bookmark: LibraryItem
    @EnvironmentObject private var moduleManager: ModuleManager
    @EnvironmentObject private var libraryManager: LibraryManager
    
    var body: some View {
        if let module = moduleManager.modules.first(where: { $0.id.uuidString == bookmark.moduleId }) {
            ZStack {
                LazyImage(url: URL(string: bookmark.imageUrl)) { state in
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
                            .frame(width: 162, height: 243)
                    }
                }
                .overlay(
                    ZStack {
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
                    }
                    .padding(8),
                    alignment: .topLeading
                )
                
                VStack {
                    Spacer()
                    Text(bookmark.title)
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
                .frame(width: 162)
            }
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .padding(4)
            .contextMenu {
                Button(role: .destructive, action: {
                    libraryManager.removeBookmark(item: bookmark)
                }) {
                    Label("Remove from Bookmarks", systemImage: "trash")
                }
            }
        }
    }
}

private extension View {
    func withNavigationBarModifiers() -> some View {
        self
            .navigationBarBackButtonHidden(true)
            .navigationBarTitleDisplayMode(.inline)
    }
    
    func withGridPadding() -> some View {
        self
            .padding(.top)
            .padding()
            .scrollViewBottomPadding()
    }
}
