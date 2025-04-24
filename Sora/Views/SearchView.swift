//
//  SearchView.swift
//  Sora
//
//  Created by Francesco on 05/01/25.
//

import SwiftUI
import Kingfisher

struct SearchItem: Identifiable {
    let id = UUID()
    let title: String
    let imageUrl: String
    let href: String
}

/* Preview code, ignore
struct SearchView_Previews: PreviewProvider {
    static var previews: some View {
        SearchView()
            .environmentObject(ModuleManager())
    }
}
*/

extension View {
    func trackScrollTwo() -> some View {
        self.modifier(ScrollTrackingModifierTwo())
    }
}

struct ScrollTrackingModifierTwo: ViewModifier {
    @State private var lastOffset: CGFloat = 0
    @State private var isScrollingDown: Bool = false
    @State private var isAtTop: Bool = true
    
    func body(content: Content) -> some View {
        content
            .background(
                GeometryReader { proxy in
                    Color.clear
                        .preference(key: ScrollOffsetKey.self, value: proxy.frame(in: .global).minY)
                        .onPreferenceChange(ScrollOffsetKey.self) { value in
                            let delta = lastOffset - value
                            
                            if value >= 0 {
                                isAtTop = true
                            } else {
                                isAtTop = false
                            }
                            
                            if delta > 10 && !isAtTop {
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                    ScrollState.shared.hideTabBar = true
                                }
                            }
                            else if delta < -10 && !isAtTop {
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                    ScrollState.shared.hideTabBar = false
                                }
                            }
                            
                            lastOffset = value
                        }
                }
            )
            .onAppear {
                lastOffset = 0
                DispatchQueue.main.asyncAfter(deadline: .now()) {
                    ScrollState.shared.hideTabBar = false
                }
            }
    }
}



struct ScrollOffsetKeyTwo: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

struct RoundedCorner: Shape {
    var radius: CGFloat = .infinity
    var corners: UIRectCorner = .allCorners

    func path(in rect: CGRect) -> Path {
        let path = UIBezierPath(
            roundedRect: rect,
            byRoundingCorners: corners,
            cornerRadii: CGSize(width: radius, height: radius)
        )
        return Path(path.cgPath)
    }
}

struct SearchView: View {
    @AppStorage("selectedModuleId") private var selectedModuleId: String?
    @AppStorage("mediaColumnsPortrait") private var mediaColumnsPortrait: Int = 2
    @AppStorage("mediaColumnsLandscape") private var mediaColumnsLandscape: Int = 4

    @StateObject private var jsController = JSController()
    @EnvironmentObject var moduleManager: ModuleManager
    @Environment(\.verticalSizeClass) var verticalSizeClass
    @Environment(\.colorScheme) private var colorScheme

    @State private var searchItems: [SearchItem] = []
    @State private var selectedSearchItem: SearchItem?
    @State private var isSearching = false
    @State private var searchText = ""
    @State private var hasNoResults = false
    @State private var isLandscape: Bool = UIDevice.current.orientation.isLandscape
    @State private var isModuleSelectorPresented = false

    private var selectedModule: ScrapingModule? {
        guard let id = selectedModuleId else { return nil }
        return moduleManager.modules.first { $0.id.uuidString == id }
    }

    private var columnsCount: Int {
        if UIDevice.current.userInterfaceIdiom == .pad {
            let isLandscape = UIScreen.main.bounds.width > UIScreen.main.bounds.height
            return isLandscape ? mediaColumnsLandscape : mediaColumnsPortrait
        } else {
            return verticalSizeClass == .compact ? mediaColumnsLandscape : mediaColumnsPortrait
        }
    }

    private var cellWidth: CGFloat {
        let keyWindow = UIApplication.shared.connectedScenes
            .compactMap { ($0 as? UIWindowScene)?.windows.first(where: { $0.isKeyWindow }) }
            .first
        let safeAreaInsets = keyWindow?.safeAreaInsets ?? .zero
        let safeWidth = UIScreen.main.bounds.width - safeAreaInsets.left - safeAreaInsets.right
        let totalSpacing: CGFloat = 16 * CGFloat(columnsCount + 1)
        let availableWidth = safeWidth - totalSpacing
        return availableWidth / CGFloat(columnsCount)
    }

    private var containerHeight: CGFloat {
        if searchText.isEmpty {
            if selectedModule == nil {
                return 250
            } else {
                return 150
            }
        } else {
            return UIScreen.main.bounds.height - 75
        }
    }
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                VStack {
                    HStack {
                        SearchBar(text: $searchText, onSearchButtonClicked: performSearch)
                            .padding(.leading)
                            .padding(.trailing, 16) // Always symmetric padding now
                            .disabled(selectedModule == nil)
                            .padding(.top)
                    }

                    if selectedModule == nil && searchText.isEmpty {
                        VStack(spacing: 8) {
                            Image(systemName: "questionmark.app")
                                .font(.largeTitle)
                                .foregroundColor(.secondary)
                            Text("No Module Selected")
                                .font(.headline)
                            Text("Please select a module from settings")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .padding()
                        .frame(maxWidth: .infinity)
                    }
                }

                .padding(.bottom)
                .background(
                    Color(.systemBackground)
                        .opacity(0.95)
                        .clipShape(RoundedCorner(radius: 20, corners: [.topLeft, .topRight, .bottomLeft, .bottomRight]))
                        .overlay(
                            RoundedCorner(radius: 20, corners: [.topLeft, .topRight, .bottomLeft, .bottomRight])
                                .stroke(Color.secondary.opacity(0.2), lineWidth: 0.5)
                        )
                        .padding(.horizontal, 16)
                        .shadow(color: colorScheme == .dark ? Color(.label).opacity(0.1) : Color.black.opacity(0.1), radius: 4, x: 0, y: 2)
                )

                ScrollView {
                    VStack(spacing: 16) {
                        if !searchText.isEmpty {
                            if isSearching {
                                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 16), count: columnsCount), spacing: 16) {
                                    ForEach(0..<columnsCount*4, id: \.self) { _ in
                                        SearchSkeletonCell(cellWidth: cellWidth)
                                    }
                                }
                                .padding()
                            } else if hasNoResults {
                                VStack(spacing: 8) {
                                    Image(systemName: "magnifyingglass")
                                        .font(.largeTitle)
                                        .foregroundColor(.secondary)
                                    Text("No Results Found")
                                        .font(.headline)
                                    Text("Try different keywords")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                .padding()
                                .frame(maxWidth: .infinity)
                            } else {
                                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 16), count: columnsCount), spacing: 16) {
                                    ForEach(searchItems) { item in
                                        NavigationLink(destination: MediaInfoView(title: item.title, imageUrl: item.imageUrl, href: item.href, module: selectedModule!)) {
                                            ZStack(alignment: .bottom) {
                                                KFImage(URL(string: item.imageUrl))
                                                    .resizable()
                                                    .aspectRatio(contentMode: .fill)
                                                    .frame(width: cellWidth, height: cellWidth * 3 / 2)
                                                    .clipped()
                                                    .overlay(
                                                        LinearGradient(
                                                            gradient: Gradient(colors: [Color.black.opacity(0.6), Color.black.opacity(0.0)]),
                                                            startPoint: .bottom,
                                                            endPoint: .top
                                                        )
                                                    )
                                                
                                                Text(item.title)
                                                    .font(.subheadline.weight(.semibold))
                                                    .foregroundColor(.white)
                                                    .padding(8)
                                                    .frame(maxWidth: .infinity, alignment: .leading)
                                            }
                                            .frame(width: cellWidth, height: cellWidth * 3 / 2)
                                            .background(.ultraThinMaterial)
                                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                                            .overlay(
                                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                                    .stroke(Color.secondary.opacity(0.3), lineWidth: 1)
                                            )
                                            .shadow(color: Color.black.opacity(0.1), radius: 4, x: 0, y: 2)
                                        }
                                    }
                                }
                                .padding()
                            }
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .trackScrollTwo()
                }
            }
            .background(Color.clear)
            .navigationTitle("Search")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    modulePicker
                }
            }
        }
        .navigationViewStyle(StackNavigationViewStyle())
        .onChange(of: selectedModuleId) { _ in
            withAnimation(.easeInOut(duration: 0.3)) {
                if !searchText.isEmpty {
                    performSearch()
                }
            }
        }
        .onChange(of: searchText) { newValue in
            if newValue.isEmpty {
                searchItems = []
                hasNoResults = false
                isSearching = false
            }
        }
    }

    private var modulePicker: some View {
        Menu {
            ForEach(getModuleLanguageGroups(), id: \.self) { language in
                Menu(language) {
                    ForEach(getModulesForLanguage(language), id: \.id) { module in
                        Button {
                            selectedModuleId = module.id.uuidString
                        } label: {
                            HStack {
                                KFImage(URL(string: module.metadata.iconUrl))
                                    .resizable()
                                    .aspectRatio(contentMode: .fit)
                                    .frame(width: 20, height: 20)
                                    .cornerRadius(4)
                                Text(module.metadata.sourceName)
                                if module.id.uuidString == selectedModuleId {
                                    Image(systemName: "checkmark")
                                        .foregroundColor(.accentColor)
                                }
                            }
                        }
                    }
                }
            }
        } label: {
            HStack(spacing: 4) {
                if let selectedModule = selectedModule {
                    Text(selectedModule.metadata.sourceName)
                        .font(.headline)
                        .foregroundColor(.secondary)
                } else {
                    Text("Select Module")
                        .font(.headline)
                        .foregroundColor(.accentColor)
                }
                Image(systemName: "chevron.down")
                    .foregroundColor(.secondary)
            }
        }
        .fixedSize()
    }

    private func performSearch() {
        Logger.shared.log("Searching for: \(searchText)", type: "General")
        guard !searchText.isEmpty, let module = selectedModule else {
            searchItems = []
            hasNoResults = false
            return
        }

        isSearching = true
        hasNoResults = false
        searchItems = []

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            Task {
                do {
                    let jsContent = try moduleManager.getModuleContent(module)
                    jsController.loadScript(jsContent)
                    if module.metadata.asyncJS == true {
                        jsController.fetchJsSearchResults(keyword: searchText, module: module) { items in
                            searchItems = items
                            hasNoResults = items.isEmpty
                            isSearching = false
                        }
                    } else {
                        jsController.fetchSearchResults(keyword: searchText, module: module) { items in
                            searchItems = items
                            hasNoResults = items.isEmpty
                            isSearching = false
                        }
                    }
                } catch {
                    Logger.shared.log("Error loading module: \(error)", type: "Error")
                    isSearching = false
                    hasNoResults = true
                }
            }
        }
    }

    private func getModulesByLanguage() -> [String: [ScrapingModule]] {
        var result = [String: [ScrapingModule]]()
        for module in moduleManager.modules {
            let language = cleanLanguageName(module.metadata.language)
            result[language, default: []].append(module)
        }
        return result
    }

    private func getModuleLanguageGroups() -> [String] {
        getModulesByLanguage().keys.sorted()
    }

    private func getModulesForLanguage(_ language: String) -> [ScrapingModule] {
        getModulesByLanguage()[language] ?? []
    }

    private func cleanLanguageName(_ language: String?) -> String {
        guard let language = language else { return "Unknown" }
        let cleaned = language.replacingOccurrences(of: "\\s*\\([^\\)]*\\)", with: "", options: .regularExpression).trimmingCharacters(in: .whitespaces)
        return cleaned.isEmpty ? "Unknown" : cleaned
    }
}

struct SearchBar: View {
    @Binding var text: String
    var onSearchButtonClicked: () -> Void
    @Environment(\.colorScheme) private var colorScheme
    
    var body: some View {
        HStack {
            TextField("Search...", text: $text, onCommit: onSearchButtonClicked)
                .padding(7)
                .padding(.horizontal, 25)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color(.systemGray6))
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(colorScheme == .dark ? Color.gray.opacity(0.3) : Color.clear, lineWidth: 1)
                        )
                )
                .overlay(
                    HStack {
                        Image(systemName: "magnifyingglass")
                            .foregroundColor(.secondary)
                            .frame(minWidth: 0, maxWidth: .infinity, alignment: .leading)
                            .padding(.leading, 8)
                        
                        if !text.isEmpty {
                            Button(action: {
                                self.text = ""
                            }) {
                                Image(systemName: "multiply.circle.fill")
                                    .foregroundColor(.secondary)
                                    .padding(.trailing, 8)
                            }
                        }
                    }
                )
            .padding(.horizontal, 16)
        }
    }
}
