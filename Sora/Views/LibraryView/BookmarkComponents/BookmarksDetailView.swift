//
//  BookmarksDetailView.swift
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
    
    @State private var sortOption: SortOption = .dateCreated
    @State private var searchText: String = ""
    @State private var isSearchActive: Bool = false
    @State private var isSelecting: Bool = false
    @State private var selectedCollections: Set<UUID> = []
    @State private var isShowingCreateCollection: Bool = false
    @State private var newCollectionName: String = ""
    @State private var isShowingRenamePrompt: Bool = false
    @State private var collectionToRename: BookmarkCollection? = nil
    @State private var renameCollectionName: String = ""
    
    enum SortOption: String, CaseIterable {
        case dateCreated = "Date Created"
        case name = "Name"
        case itemCount = "Item Count"
    }
    
    var filteredAndSortedCollections: [BookmarkCollection] {
        let filtered = searchText.isEmpty ? libraryManager.collections : libraryManager.collections.filter { collection in
            collection.name.localizedCaseInsensitiveContains(searchText)
        }
        switch sortOption {
        case .dateCreated:
            return filtered.sorted { $0.dateCreated > $1.dateCreated }
        case .name:
            return filtered.sorted { $0.name.lowercased() < $1.name.lowercased() }
        case .itemCount:
            return filtered.sorted { $0.bookmarks.count > $1.bookmarks.count }
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
                    Text(LocalizedStringKey("Collections"))
                        .font(.title3)
                        .fontWeight(.bold)
                        .foregroundColor(.primary)
                        .lineLimit(1)
                        .truncationMode(.tail)
                        .layoutPriority(1)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
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
                            if !selectedCollections.isEmpty {
                                for id in selectedCollections {
                                    libraryManager.deleteCollection(id: id)
                                }
                                selectedCollections.removeAll()
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
                    Button(action: {
                        isShowingCreateCollection = true
                    }) {
                        Image(systemName: "folder.badge.plus")
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
                .layoutPriority(0)
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
                        TextField(LocalizedStringKey("Search collections..."), text: $searchText)
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
            
            if filteredAndSortedCollections.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "folder")
                        .font(.largeTitle)
                        .foregroundColor(.secondary)
                    Text(LocalizedStringKey("No Collections"))
                        .font(.headline)
                    Text(LocalizedStringKey("Create a collection to organize your bookmarks"))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView(showsIndicators: false) {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 162), spacing: 16)], spacing: 16) {
                        ForEach(filteredAndSortedCollections) { collection in
                            if isSelecting {
                                Button(action: {
                                    if selectedCollections.contains(collection.id) {
                                        selectedCollections.remove(collection.id)
                                    } else {
                                        selectedCollections.insert(collection.id)
                                    }
                                }) {
                                    BookmarkCollectionGridCell(collection: collection, width: 162, height: 162)
                                        .overlay(
                                            selectedCollections.contains(collection.id) ?
                                            ZStack {
                                                Circle()
                                                    .fill(Color.white)
                                                    .frame(width: 32, height: 32)
                                                Image(systemName: "checkmark")
                                                    .resizable()
                                                    .scaledToFit()
                                                    .frame(width: 18, height: 18)
                                                    .foregroundColor(.black)
                                            }
                                            .padding(8)
                                            : nil,
                                            alignment: .topTrailing
                                        )
                                }
                                .contextMenu {
                                    Button(LocalizedStringKey("Rename")) {
                                        collectionToRename = collection
                                        renameCollectionName = collection.name
                                        isShowingRenamePrompt = true
                                    }
                                    Button(role: .destructive) {
                                        libraryManager.deleteCollection(id: collection.id)
                                    } label: {
                                        Label(LocalizedStringKey("Delete"), systemImage: "trash")
                                    }
                                }
                            } else {
                                NavigationLink(destination: CollectionDetailView(collection: collection)) {
                                    BookmarkCollectionGridCell(collection: collection, width: 162, height: 162)
                                }
                                .contextMenu {
                                    Button(LocalizedStringKey("Rename")) {
                                        collectionToRename = collection
                                        renameCollectionName = collection.name
                                        isShowingRenamePrompt = true
                                    }
                                    Button(role: .destructive) {
                                        libraryManager.deleteCollection(id: collection.id)
                                    } label: {
                                        Label(LocalizedStringKey("Delete"), systemImage: "trash")
                                    }
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top)
                    .scrollViewBottomPadding()
                }
            }
        }
        .navigationBarBackButtonHidden(true)
        .navigationBarTitleDisplayMode(.inline)
        .alert(LocalizedStringKey("Create Collection"), isPresented: $isShowingCreateCollection) {
            TextField(LocalizedStringKey("Collection Name"), text: $newCollectionName)
            Button(LocalizedStringKey("Cancel"), role: .cancel) {
                newCollectionName = ""
            }
            Button(LocalizedStringKey("Create")) {
                if !newCollectionName.isEmpty {
                    libraryManager.createCollection(name: newCollectionName)
                    newCollectionName = ""
                }
            }
        }
        .alert(LocalizedStringKey("Rename Collection"), isPresented: $isShowingRenamePrompt, presenting: collectionToRename) { collection in
            TextField(LocalizedStringKey("Collection Name"), text: $renameCollectionName)
            Button(LocalizedStringKey("Cancel"), role: .cancel) {
                collectionToRename = nil
                renameCollectionName = ""
            }
            Button(LocalizedStringKey("Rename")) {
                if let collection = collectionToRename, !renameCollectionName.isEmpty {
                    libraryManager.renameCollection(id: collection.id, newName: renameCollectionName)
                    collectionToRename = nil
                    renameCollectionName = ""
                }
            }
        } message: { _ in EmptyView() }
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
    let isSelecting: Bool
    @Binding var selectedBookmarks: Set<LibraryItem.ID>
    private let columns = [GridItem(.adaptive(minimum: 150))]
    var body: some View {
        ScrollView(showsIndicators: false) {
            LazyVGrid(columns: columns, spacing: 16) {
                ForEach(bookmarks) { bookmark in
                    BookmarksDetailGridCell(bookmark: bookmark, moduleManager: moduleManager, isSelecting: isSelecting, selectedBookmarks: $selectedBookmarks)
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
    let isSelecting: Bool
    @Binding var selectedBookmarks: Set<LibraryItem.ID>
    
    var isSelected: Bool {
        selectedBookmarks.contains(bookmark.id)
    }
    
    var body: some View {
        if let module = moduleManager.modules.first(where: { $0.id.uuidString == bookmark.moduleId }) {
            if isSelecting {
                Button(action: {
                    if isSelected {
                        selectedBookmarks.remove(bookmark.id)
                    } else {
                        selectedBookmarks.insert(bookmark.id)
                    }
                }) {
                    ZStack(alignment: .topTrailing) {
                        BookmarkCell(bookmark: bookmark)
                        if isSelected {
                            ZStack {
                                Circle()
                                    .fill(Color.white)
                                    .frame(width: 32, height: 32)
                                Image(systemName: "checkmark")
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: 18, height: 18)
                                    .foregroundColor(.accentColor)
                            }
                            .offset(x: -8, y: 8)
                        }
                    }
                }
            } else {
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
} 
