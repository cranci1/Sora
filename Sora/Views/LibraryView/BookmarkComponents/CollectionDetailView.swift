//
//  CollectionDetailView.swift
//  Sora
//
//  Created by paul on 18/06/25.
//

import SwiftUI
import NukeUI

struct CollectionDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var libraryManager: LibraryManager
    @EnvironmentObject private var moduleManager: ModuleManager

    
    let collection: BookmarkCollection
    @State private var sortOption: SortOption = .dateAdded
    @State private var searchText: String = ""
    @State private var isSearchActive: Bool = false
    @State private var isSelecting: Bool = false
    @State private var selectedBookmarks: Set<LibraryItem.ID> = []
    @State private var isActive: Bool = false
    
    enum SortOption: String, CaseIterable {
        case dateAdded = "Date Added"
        case title = "Title"
        case source = "Source"
    }
    
    private var filteredAndSortedBookmarks: [LibraryItem] {
        let validBookmarks = collection.bookmarks.filter { bookmark in
            moduleManager.modules.contains { $0.id.uuidString == bookmark.moduleId }
        }
        
        let filtered = searchText.isEmpty ? validBookmarks : validBookmarks.filter { item in
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
                    Text(collection.name)
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
                            if !selectedBookmarks.isEmpty {
                                for id in selectedBookmarks {
                                    if collection.bookmarks.contains(where: { $0.id == id }) {
                                        libraryManager.removeBookmarkFromCollection(bookmarkId: id, collectionId: collection.id)
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
                        TextField(LocalizedStringKey("Search bookmarks..."), text: $searchText)
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
            
            if filteredAndSortedBookmarks.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "bookmark")
                        .font(.largeTitle)
                        .foregroundColor(.secondary)
                    Text("No Bookmarks")
                        .font(.headline)
                    Text("Add bookmarks to this collection")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView(showsIndicators: false) {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 150))], spacing: 16) {
                        ForEach(filteredAndSortedBookmarks) { bookmark in
                            if let module = moduleManager.modules.first(where: { $0.id.uuidString == bookmark.moduleId }) {
                                if isSelecting {
                                    Button(action: {
                                        if selectedBookmarks.contains(bookmark.id) {
                                            selectedBookmarks.remove(bookmark.id)
                                        } else {
                                            selectedBookmarks.insert(bookmark.id)
                                        }
                                    }) {
                                        BookmarkGridItemView(item: bookmark, module: module)
                                            .overlay(
                                                selectedBookmarks.contains(bookmark.id) ?
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
                                        Button(role: .destructive) {
                                            libraryManager.removeBookmarkFromCollection(bookmarkId: bookmark.id, collectionId: collection.id)
                                        } label: {
                                            Label("Delete", systemImage: "trash")
                                        }
                                    }
                                } else {
                                    NavigationLink(destination: MediaInfoView(
                                        title: bookmark.title,
                                        imageUrl: bookmark.imageUrl,
                                        href: bookmark.href,
                                        module: module
                                    )) {
                                        BookmarkGridItemView(item: bookmark, module: module)
                                    }
                                    .isDetailLink(true)
                                    .contextMenu {
                                        Button(role: .destructive) {
                                            libraryManager.removeBookmarkFromCollection(bookmarkId: bookmark.id, collectionId: collection.id)
                                        } label: {
                                            Label("Delete", systemImage: "trash")
                                        }
                                    }
                                }
                            }
                        }
                    }
                    .padding()
                    .scrollViewBottomPadding()
                }
            }
        }
        .navigationBarBackButtonHidden(true)
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            isActive = true
            if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
               let window = windowScene.windows.first,
               let navigationController = window.rootViewController?.children.first as? UINavigationController {
                navigationController.interactivePopGestureRecognizer?.isEnabled = true
                navigationController.interactivePopGestureRecognizer?.delegate = nil
            }
            
            let isMediaInfoActive = UserDefaults.standard.bool(forKey: "isMediaInfoActive")
            let isReaderActive = UserDefaults.standard.bool(forKey: "isReaderActive")
            if !isMediaInfoActive && !isReaderActive {
                NotificationCenter.default.post(name: .showTabBar, object: nil)
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.02) {
                let isMediaInfoActive = UserDefaults.standard.bool(forKey: "isMediaInfoActive")
                let isReaderActive = UserDefaults.standard.bool(forKey: "isReaderActive")
                if !isMediaInfoActive && !isReaderActive {
                    NotificationCenter.default.post(name: .showTabBar, object: nil)
                }
            }
        }
        .onReceive(Timer.publish(every: 0.1, on: .main, in: .common).autoconnect()) { _ in
            let isMediaInfoActive = UserDefaults.standard.bool(forKey: "isMediaInfoActive")
            let isReaderActive = UserDefaults.standard.bool(forKey: "isReaderActive")
            if isActive && !isMediaInfoActive && !isReaderActive {
                NotificationCenter.default.post(name: .showTabBar, object: nil)
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)) { _ in
            isActive = true
            let isMediaInfoActive = UserDefaults.standard.bool(forKey: "isMediaInfoActive")
            let isReaderActive = UserDefaults.standard.bool(forKey: "isReaderActive")
            if !isMediaInfoActive && !isReaderActive {
                NotificationCenter.default.post(name: .showTabBar, object: nil)
            }
        }
    }
} 
