//
//  AllReading.swift
//  Sora
//
//  Created by paul on 26/06/25.
//

import SwiftUI
import NukeUI

struct AllReadingView: View {
    @Environment(\.dismiss) private var dismiss


    @State private var continueReadingItems: [ContinueReadingItem] = []
    @State private var isRefreshing: Bool = false
    @State private var sortOption: SortOption = .dateAdded
    @State private var searchText: String = ""
    @State private var isSearchActive: Bool = false
    @State private var isSelecting: Bool = false
    @State private var selectedItems: Set<ContinueReadingItem.ID> = []
    @Environment(\.scenePhase) private var scenePhase
    
    enum SortOption: String, CaseIterable {
        case dateAdded = "Recently Added"
        case title = "Novel Title"
        case progress = "Read Progress"
    }
    
    var filteredAndSortedItems: [ContinueReadingItem] {
        let filtered = searchText.isEmpty ? continueReadingItems : continueReadingItems.filter { item in
            item.mediaTitle.localizedCaseInsensitiveContains(searchText)
        }
        switch sortOption {
        case .dateAdded:
            return filtered.sorted { $0.lastReadDate > $1.lastReadDate }
        case .title:
            return filtered.sorted { $0.mediaTitle.lowercased() < $1.mediaTitle.lowercased() }
        case .progress:
            return filtered.sorted { $0.progress > $1.progress }
        }
    }
    
    var body: some View {
        VStack(alignment: .leading) {
            HStack {
                Button(action: {
                    dismiss()
                }) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 24))
                        .foregroundColor(.primary)
                }
                
                Button(action: {
                    dismiss()
                }) {
                    Text(LocalizedStringKey("All Reading"))
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
                            if !selectedItems.isEmpty {
                                for id in selectedItems {
                                    if let item = continueReadingItems.first(where: { $0.id == id }) {
                                        ContinueReadingManager.shared.remove(item: item)
                                    }
                                }
                                selectedItems.removeAll()
                                fetchContinueReading()
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
                        TextField(LocalizedStringKey("Search reading..."), text: $searchText)
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
            
            ScrollView {
                LazyVStack(spacing: 12) {
                    if filteredAndSortedItems.isEmpty {
                        emptyStateView
                    } else {
                        ForEach(filteredAndSortedItems) { item in
                            FullWidthContinueReadingCell(
                                item: item, 
                                markAsRead: {
                                    markContinueReadingItemAsRead(item: item)
                                }, 
                                removeItem: {
                                    removeContinueReadingItem(item: item)
                                },
                                isSelecting: isSelecting,
                                selectedItems: $selectedItems
                            )
                        }
                    }
                }
                .padding(.top)
                .padding(.horizontal)
            }
            .scrollViewBottomPadding()
        }
        .navigationBarBackButtonHidden(true)
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            fetchContinueReading()
            
            NotificationCenter.default.post(name: .showTabBar, object: nil)
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
        
        for (index, item) in continueReadingItems.enumerated() {
            print("Reading item \(index): Title: \(item.mediaTitle), Image URL: \(item.imageUrl)")
        }
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

struct FullWidthContinueReadingCell: View {
    let item: ContinueReadingItem
    var markAsRead: () -> Void
    var removeItem: () -> Void
    var isSelecting: Bool
    var selectedItems: Binding<Set<ContinueReadingItem.ID>>
    
    var isSelected: Bool {
        selectedItems.wrappedValue.contains(item.id)
    }
    
    private var imageURL: URL {
        print("Processing image URL: \(item.imageUrl)")
        
        if !item.imageUrl.isEmpty {
            if let url = URL(string: item.imageUrl) {
                print("Valid URL: \(url)")
                return url
            }
            
            if let encodedUrlString = item.imageUrl.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
               let url = URL(string: encodedUrlString) {
                print("Using encoded URL: \(encodedUrlString)")
                return url
            }
        }
        
        print("Using fallback URL")
        return URL(string: "https://raw.githubusercontent.com/cranci1/Sora/refs/heads/main/assets/banner2.png")!
    }
    
    @MainActor
    var body: some View {
        Group {
            if isSelecting {
                Button(action: {
                    if isSelected {
                        selectedItems.wrappedValue.remove(item.id)
                    } else {
                        selectedItems.wrappedValue.insert(item.id)
                    }
                }) {
                    ZStack(alignment: .topTrailing) {
                        cellContent
                        if isSelected {
                            Image(systemName: "checkmark.circle.fill")
                                .resizable()
                                .frame(width: 32, height: 32)
                                .foregroundColor(.black)
                                .background(Color.white.clipShape(Circle()).opacity(0.8))
                                .offset(x: -8, y: 8)
                        }
                    }
                }
            } else {
                NavigationLink(destination: ReaderView(
                    moduleId: item.moduleId,
                    chapterHref: item.href,
                    chapterTitle: item.chapterTitle,
                    mediaTitle: item.mediaTitle,
                    chapterNumber: item.chapterNumber
                )) {
                    cellContent
                }
                .simultaneousGesture(TapGesture().onEnded {
                    UserDefaults.standard.set(true, forKey: "navigatingToReaderView")
                })
            }
        }
        .contextMenu {
            Button(action: { markAsRead() }) {
                Label("Mark as Read", systemImage: "checkmark.circle")
            }
            Button(role: .destructive, action: { removeItem() }) {
                Label("Remove from Continue Reading", systemImage: "trash")
            }
        }
    }
    
    @MainActor
    private var cellContent: some View {
        GeometryReader { geometry in
            ZStack {
                LazyImage(url: imageURL) { state in
                    if let image = state.imageContainer?.image {
                        Image(uiImage: image)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: geometry.size.width, height: 157.03)
                            .blur(radius: 3)
                            .opacity(0.7)
                    } else {
                        Rectangle()
                            .fill(Color.gray.opacity(0.3))
                            .frame(width: geometry.size.width, height: 157.03)
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
                    .frame(width: geometry.size.width, height: 157.03)
                
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
                    .frame(width: geometry.size.width * 0.6, alignment: .leading)
                    
                    LazyImage(url: imageURL) { state in
                        if let image = state.imageContainer?.image {
                            Image(uiImage: image)
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(width: geometry.size.width * 0.4, height: 157.03)
                                .clipped()
                        } else {
                            Rectangle()
                                .fill(Color.gray.opacity(0.3))
                                .frame(width: geometry.size.width * 0.4, height: 157.03)
                        }
                    }
                    .onAppear {
                        print("Right image loading: \(imageURL)")
                    }
                    .frame(width: geometry.size.width * 0.4, height: 157.03)
                }
            }
            .frame(height: 157.03)
            .cornerRadius(10)
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(Color.gray.opacity(0.3), lineWidth: 0.5)
            )
        }
        .frame(height: 157.03)
    }
} 
