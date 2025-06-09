//
//  MediaInfoView.swift
//  Sora
//
//  Created by Francesco on 05/01/25.
//

import NukeUI
import SwiftUI
import SafariServices

private let tmdbFetcher = TMDBFetcher()

struct MediaItem: Identifiable {
    let id = UUID()
    let description: String
    let aliases: String
    let airdate: String
}

struct MediaInfoView: View {
    let title: String
    @State var imageUrl: String
    let href: String
    let module: ScrapingModule
    
    @State var aliases: String = ""
    @State var synopsis: String = ""
    @State var airdate: String = ""
    @State var episodeLinks: [EpisodeLink] = []
    @State var itemID: Int?
    @State var tmdbID: Int?
    
    @State var isLoading: Bool = true
    @State var showFullSynopsis: Bool = false
    @State var hasFetched: Bool = false
    @State var isRefetching: Bool = true
    @State var isFetchingEpisode: Bool = false
    
    @State private var refreshTrigger: Bool = false
    @State private var buttonRefreshTrigger: Bool = false
    
    @State private var selectedEpisodeNumber: Int = 0
    @State private var selectedEpisodeImage: String = ""
    @State private var selectedSeason: Int = 0
    
    @AppStorage("externalPlayer") private var externalPlayer: String = "Default"
    @AppStorage("episodeChunkSize") private var episodeChunkSize: Int = 100
    
    private var selectedRangeKey: String  { "selectedRangeStart_\(href)" }
    private var selectedSeasonKey: String { "selectedSeason_\(href)" }
    @State private var selectedRange: Range<Int> = {
        let size = UserDefaults.standard.integer(forKey: "episodeChunkSize")
        let chunk = size == 0 ? 100 : size
        return 0..<chunk
    }()
    
    @State private var isModuleSelectorPresented = false
    @State private var isError = false
    @State private var isMatchingPresented = false
    @State private var matchedTitle: String? = nil
    
    @ObservedObject private var jsController = JSController.shared
    @EnvironmentObject var moduleManager: ModuleManager
    @EnvironmentObject private var libraryManager: LibraryManager
    @EnvironmentObject var tabBarController: TabBarController
    
    @State private var showSettingsMenu = false
    @State private var customAniListID: Int?
    @State private var showStreamLoadingView: Bool = false
    @State private var currentStreamTitle: String = ""
    
    @State private var activeFetchID: UUID? = nil
    @Environment(\.dismiss) private var dismiss
    
    @State private var showLoadingAlert: Bool = false
    
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.verticalSizeClass) private var verticalSizeClass
    @AppStorage("selectedAppearance") private var selectedAppearance: Appearance = .system
    
    @State private var isMultiSelectMode: Bool = false
    @State private var selectedEpisodes: Set<Int> = []
    @State private var showRangeInput: Bool = false
    @State private var isBulkDownloading: Bool = false
    @State private var bulkDownloadProgress: String = ""
    @State private var tmdbType: TMDBFetcher.MediaType? = nil
    
    private var isGroupedBySeasons: Bool {
        return groupedEpisodes().count > 1
    }
    
    private var isCompactLayout: Bool {
        return verticalSizeClass == .compact
    }
    
    private var useIconOnlyButtons: Bool {
        if UIDevice.current.userInterfaceIdiom == .pad {
            return false
        }
        return verticalSizeClass == .regular
    }
    
    private var multiselectButtonSpacing: CGFloat {
        return isCompactLayout ? 16 : 12
    }
    
    private var multiselectPadding: CGFloat {
        return isCompactLayout ? 20 : 16
    }
    
    var body: some View {
        ZStack {
            Group {
                if isLoading {
                    ProgressView()
                        .padding()
                } else {
                    mainScrollView
                }
            }
            .navigationBarHidden(true)
            .ignoresSafeArea(.container, edges: .top)
            .onAppear {
                buttonRefreshTrigger.toggle()
                tabBarController.hideTabBar()
            }
            .onChange(of: selectedRange) { newValue in
                UserDefaults.standard.set(newValue.lowerBound, forKey: selectedRangeKey)
            }
            .onChange(of: selectedSeason) { newValue in
                UserDefaults.standard.set(newValue, forKey: selectedSeasonKey)
            }
            .onDisappear(){
                tabBarController.showTabBar()
            }
            .task {
                guard !hasFetched else { return }
                
                let savedCustomID = UserDefaults.standard.integer(forKey: "custom_anilist_id_\(href)")
                if savedCustomID != 0 { customAniListID = savedCustomID }
                if let savedPoster = UserDefaults.standard.string(forKey: "tmdbPosterURL_\(href)") {
                    imageUrl = savedPoster
                }
                
                DropManager.shared.showDrop(title: "Fetching Data", subtitle: "Please wait while fetching.", duration: 0.5, icon: UIImage(systemName: "arrow.triangle.2.circlepath"))
                fetchDetails()

                if savedCustomID != 0 {
                    itemID = savedCustomID
                } else {
                    fetchMetadataIDIfNeeded()
                }
                
                hasFetched = true
                AnalyticsManager.shared.sendEvent(
                    event: "MediaInfoView",
                    additionalData: ["title": title]
                )
            }
            .alert("Loading Stream", isPresented: $showLoadingAlert) {
                Button("Cancel", role: .cancel) {
                    activeFetchID = nil
                    isFetchingEpisode = false
                    showStreamLoadingView = false
                }
            } message: {
                HStack {
                    Text("Loading Episode \(selectedEpisodeNumber)...")
                    ProgressView()
                        .padding(.top, 8)
                }
            }
            .onDisappear {
                activeFetchID = nil
                isFetchingEpisode = false
                showStreamLoadingView = false
            }
            
            VStack {
                HStack {
                    Button(action: {
                        dismiss()
                    }) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 24))
                            .foregroundColor(.primary)
                            .padding(12)
                            .background(Color.gray.opacity(0.2))
                            .clipShape(Circle())
                            .circularGradientOutline()
                    }
                    .padding(.top, 8)
                    .padding(.leading, 16)
                    
                    Spacer()
                }
                Spacer()
            }
        }
    }
    
    @ViewBuilder
    private var mainScrollView: some View {
        ScrollView {
            ZStack(alignment: .top) {
                LazyImage(url: URL(string: imageUrl)) { state in
                    if let uiImage = state.imageContainer?.image {
                        Image(uiImage: uiImage)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: UIScreen.main.bounds.width, height: 700)
                            .clipped()
                    } else {
                        Rectangle()
                            .fill(Color.gray.opacity(0.3))
                            .shimmering()
                            .frame(width: UIScreen.main.bounds.width, height: 700)
                            .clipped()
                    }
                }
                
                VStack(spacing: 0) {
                    Rectangle()
                        .fill(Color.clear)
                        .frame(height: 400)
                    LazyVStack(alignment: .leading, spacing: 16) {
                        headerSection
                        if !episodeLinks.isEmpty {
                            episodesSection
                        } else {
                            noEpisodesSection
                        }
                    }
                    .padding()
                    .background(
                        LinearGradient(
                            gradient: Gradient(stops: [
                                .init(color: (colorScheme == .dark ? Color.black : Color.white).opacity(0.0), location: 0.0),
                                .init(color: (colorScheme == .dark ? Color.black : Color.white).opacity(0.5), location: 0.2),
                                .init(color: (colorScheme == .dark ? Color.black : Color.white).opacity(0.8), location: 0.5),
                                .init(color: (colorScheme == .dark ? Color.black : Color.white), location: 1.0)
                            ]),
                            startPoint: .top,
                            endPoint: .bottom
                        )
                            .clipShape(RoundedRectangle(cornerRadius: 0))
                            .shadow(color: (colorScheme == .dark ? Color.black : Color.white).opacity(1), radius: 10, x: 0, y: 10)
                    )
                }
            }
        }
        .onAppear {
            UIScrollView.appearance().bounces = false
        }
    }
    
    @ViewBuilder
    private var headerSection: some View {
        LazyVStack(alignment: .leading, spacing: 8) {
            Spacer()
            HStack(spacing: 16) {
                
                if !airdate.isEmpty && airdate != "N/A" && airdate != "No Data" {
                    HStack(spacing: 4) {
                        Image(systemName: "calendar")
                            .foregroundColor(.accentColor)
                        
                        Text(airdate)
                            .font(.system(size: 14))
                            .foregroundColor(.accentColor)
                    }
                }
                
                Spacer()
                
            }
            Text(title)
                .font(.system(size: 28, weight: .bold))
                .foregroundColor(.primary)
                .lineLimit(3)
                .onLongPressGesture {
                    UIPasteboard.general.string = title
                    DropManager.shared.showDrop(title: "Copied to Clipboard", subtitle: "", duration: 1.0, icon: UIImage(systemName: "doc.on.clipboard.fill"))
                }
            
            if !synopsis.isEmpty {
                HStack(alignment: .bottom) {
                    Text(synopsis)
                        .font(.system(size: 16))
                        .foregroundColor(.secondary)
                        .lineLimit(showFullSynopsis ? nil : 3)
                        .animation(nil, value: showFullSynopsis)
                    
                    Text(showFullSynopsis ? "LESS" : "MORE")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.accentColor)
                        .animation(.easeInOut(duration: 0.3), value: showFullSynopsis)
                }
                .onTapGesture {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        showFullSynopsis.toggle()
                    }
                }
            }
            
            playAndBookmarkSection
            
            if episodeLinks.count == 1 {
                VStack(spacing: 12) {
                    HStack(spacing: 12) {
                        Button(action: {
                            if let ep = episodeLinks.first {
                                let lastPlayedTime = UserDefaults.standard.double(forKey: "lastPlayedTime_\(ep.href)")
                                let totalTime = UserDefaults.standard.double(forKey: "totalTime_\(ep.href)")
                                let progress = totalTime > 0 ? lastPlayedTime / totalTime : 0
                                
                                if progress <= 0.9 {
                                    UserDefaults.standard.set(99999999.0, forKey: "lastPlayedTime_\(ep.href)")
                                    UserDefaults.standard.set(99999999.0, forKey: "totalTime_\(ep.href)")
                                    DropManager.shared.showDrop(title: "Marked as Watched", subtitle: "", duration: 1.0, icon: UIImage(systemName: "checkmark.circle.fill"))
                                } else {
                                    UserDefaults.standard.set(0.0, forKey: "lastPlayedTime_\(ep.href)")
                                    UserDefaults.standard.set(0.0, forKey: "totalTime_\(ep.href)")
                                    DropManager.shared.showDrop(title: "Progress Reset", subtitle: "", duration: 1.0, icon: UIImage(systemName: "arrow.counterclockwise"))
                                }
                            }
                        }) {
                            HStack(spacing: 4) {
                                Image(systemName: {
                                    if let ep = episodeLinks.first {
                                        let lastPlayedTime = UserDefaults.standard.double(forKey: "lastPlayedTime_\(ep.href)")
                                        let totalTime = UserDefaults.standard.double(forKey: "totalTime_\(ep.href)")
                                        let progress = totalTime > 0 ? lastPlayedTime / totalTime : 0
                                        return progress <= 0.9 ? "checkmark.circle" : "arrow.counterclockwise"
                                    }
                                    return "checkmark.circle"
                                }())
                                    .foregroundColor(.primary)
                                Text({
                                    if let ep = episodeLinks.first {
                                        let lastPlayedTime = UserDefaults.standard.double(forKey: "lastPlayedTime_\(ep.href)")
                                        let totalTime = UserDefaults.standard.double(forKey: "totalTime_\(ep.href)")
                                        let progress = totalTime > 0 ? lastPlayedTime / totalTime : 0
                                        return progress <= 0.9 ? "Mark watched" : "Reset progress"
                                    }
                                    return "Mark watched"
                                }())
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundColor(.primary)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 6)
                            .background(Color.gray.opacity(0.2))
                            .cornerRadius(15)
                            .gradientOutline()
                        }
                        
                        Button(action: {
                            if let ep = episodeLinks.first {
                                let downloadStatus = jsController.isEpisodeDownloadedOrInProgress(
                                    showTitle: title,
                                    episodeNumber: ep.number,
                                    season: 1
                                )
                                
                                if downloadStatus == .notDownloaded {
                                    selectedEpisodeNumber = ep.number
                                    startBulkDownload()
                                    DropManager.shared.showDrop(title: "Starting Download", subtitle: "", duration: 1.0, icon: UIImage(systemName: "arrow.down.circle"))
                                } else {
                                    DropManager.shared.showDrop(title: "Already Downloaded", subtitle: "", duration: 1.0, icon: UIImage(systemName: "checkmark.circle"))
                                }
                            }
                        }) {
                            HStack(spacing: 4) {
                                Image(systemName: "arrow.down.circle")
                                    .foregroundColor(.primary)
                                Text("Download")
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundColor(.primary)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 6)
                            .background(Color.gray.opacity(0.2))
                            .cornerRadius(15)
                            .gradientOutline()
                        }
                        
                        menuButton
                    }
                    Text("Why am I not seeing any episodes?")
                        .font(.caption)
                        .bold()
                        .foregroundColor(.gray)
                        .multilineTextAlignment(.leading)
                        .lineLimit(nil)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.top, 4)
                    Text("The module provided only a single episode, this is most likely a movie, so we decided to make separate screens for these cases.")
                        .font(.caption)
                        .foregroundColor(.gray)
                        .multilineTextAlignment(.leading)
                        .lineLimit(nil)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.top, 4)
                }
            }
        }
    }
    
    @ViewBuilder
    private var contentSection: some View {
        LazyVStack(alignment: .leading, spacing: 20) {
            playAndBookmarkSection
            
            if !episodeLinks.isEmpty {
                episodesSection
            } else {
                noEpisodesSection
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 20)
        .background(
            Rectangle()
                .fill(colorScheme == .dark ? Color.black : Color.white)
        )
    }
    
    @ViewBuilder
    private var sourceButton: some View {
        Button(action: {
            openSafariViewController(with: href)
        }) {
            Image(systemName: "safari")
                .resizable()
                .frame(width: 16, height: 16)
                .foregroundColor(.primary)
                .padding(6)
                .background(Color.gray.opacity(0.2))
                .clipShape(Circle())
                .circularGradientOutline()
        }
    }
    
    @ViewBuilder
    private var menuButton: some View {
        Menu {
            if let id = itemID ?? customAniListID {
                let labelText = (matchedTitle?.isEmpty == false ? matchedTitle! : "\(id)")
                Text("Matched with: \(labelText)")
                    .font(.caption)
                    .foregroundColor(.gray)
                    .padding(.vertical, 4)
            }
            
            Divider()
            
            if let _ = customAniListID {
                Button(action: {
                    customAniListID = nil
                    itemID = nil
                    matchedTitle = nil
                    fetchItemID(byTitle: cleanTitle(title)) { result in
                        switch result {
                        case .success(let id):
                            itemID = id
                        case .failure(let error):
                            Logger.shared.log("Failed to fetch AniList ID: \(error)")
                        }
                    }
                }) {
                    Label("Reset AniList ID", systemImage: "arrow.clockwise")
                }
            }
            
            if let id = itemID ?? customAniListID {
                Button(action: {
                    if let url = URL(string: "https://anilist.co/anime/\(id)") {
                        openSafariViewController(with: url.absoluteString)
                    }
                }) {
                    Label("Open in AniList", systemImage: "link")
                }
            }
            
            if UserDefaults.standard.string(forKey: "metadataProviders") ?? "TMDB" == "AniList" {
                Button(action: {
                    isMatchingPresented = true
                }) {
                    Label("Match with AniList", systemImage: "magnifyingglass")
                }
            }
            
            Button(action: {
                fetchTMDBPosterImageAndSet()
            }) {
                Label("Use TMDB Poster Image", systemImage: "photo")
            }
            
            Divider()
            
            Button(action: {
                Logger.shared.log("""
                    Debug Info:
                    Title: \(title)
                    Href: \(href)
                    Module: \(module.metadata.sourceName)
                    AniList ID: \(itemID ?? -1)
                    Custom ID: \(customAniListID ?? -1)
                    Matched Title: \(matchedTitle ?? "—")
                    """, type: "Debug")
                DropManager.shared.showDrop(
                    title: "Debug Info Logged",
                    subtitle: "",
                    duration: 1.0,
                    icon: UIImage(systemName: "terminal")
                )
            }) {
                Label("Log Debug Info", systemImage: "terminal")
            }
        } label: {
            Image(systemName: "ellipsis")
                .resizable()
                .frame(width: 16, height: 4)
                .foregroundColor(.primary)
                .padding(12)
                .background(Color.gray.opacity(0.2))
                .clipShape(Circle())
                .circularGradientOutline()
        }
        .sheet(isPresented: $isMatchingPresented) {
            AnilistMatchPopupView(seriesTitle: title) { selectedID in
                self.customAniListID = selectedID
                self.itemID = selectedID
                UserDefaults.standard.set(selectedID, forKey: "custom_anilist_id_\(href)")
                self.fetchDetails()
                isMatchingPresented = false
            }
        }
    }
    
    @ViewBuilder
    private var playAndBookmarkSection: some View {
        HStack(spacing: 12) {
            Button(action: {
                playFirstUnwatchedEpisode()
            }) {
                HStack(spacing: 8) {
                    Image(systemName: "play.fill")
                        .foregroundColor(colorScheme == .dark ? .black : .white)
                    Text(startWatchingText)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(colorScheme == .dark ? .black : .white)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .padding(.horizontal, 20)
                .background(
                    RoundedRectangle(cornerRadius: 25)
                        .fill(Color.accentColor)
                )
            }
            .disabled(isFetchingEpisode)
            
            Button(action: {
                libraryManager.toggleBookmark(
                    title: title,
                    imageUrl: imageUrl,
                    href: href,
                    moduleId: module.id.uuidString,
                    moduleName: module.metadata.sourceName
                )
            }) {
                Image(systemName: libraryManager.isBookmarked(href: href, moduleName: module.metadata.sourceName) ? "bookmark.fill" : "bookmark")
                    .resizable()
                    .frame(width: 16, height: 22)
                    .foregroundColor(.primary)
                    .padding(12)
                    .background(Color.gray.opacity(0.2))
                    .clipShape(Circle())
                    .circularGradientOutline()
            }
        }
    }
    
    @ViewBuilder
    private var episodesSection: some View {
        if episodeLinks.count == 1 {
            EmptyView()
        } else {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Text("Episodes")
                        .font(.system(size: 22, weight: .bold))
                        .foregroundColor(.primary)
                    
                    Spacer()
                    
                    Group {
                        if !isGroupedBySeasons && episodeLinks.count <= episodeChunkSize {
                            Text("")
                                .font(.system(size: 14))
                                .foregroundColor(.secondary)
                        } else {
                            episodeNavigationSection
                        }
                    }
                    
                    HStack(spacing: 4) {
                        sourceButton
                        menuButton
                    }
                }
                
                episodeListSection
            }
        }
    }
    
    @ViewBuilder
    private var episodeNavigationSection: some View {
        Group {
            if !isGroupedBySeasons, episodeLinks.count > episodeChunkSize {
                Menu {
                    ForEach(generateRanges(), id: \.self) { range in
                        Button(action: { selectedRange = range }) {
                            Text("\(range.lowerBound + 1)-\(range.upperBound)")
                        }
                    }
                } label: {
                    Text("\(selectedRange.lowerBound + 1)-\(selectedRange.upperBound)")
                        .font(.system(size: 14))
                        .foregroundColor(.accentColor)
                }
            } else if isGroupedBySeasons {
                let seasons = groupedEpisodes()
                if seasons.count > 1 {
                    Menu {
                        ForEach(0..<seasons.count, id: \.self) { index in
                            Button(action: { selectedSeason = index }) {
                                Text("Season \(index + 1)")
                            }
                        }
                    } label: {
                        Text("Season \(selectedSeason + 1)")
                            .font(.system(size: 14))
                            .foregroundColor(.accentColor)
                    }
                }
            }
        }
    }
    
    @ViewBuilder
    private var episodeListSection: some View {
        Group {
            if isGroupedBySeasons {
                seasonsEpisodeList
            } else {
                flatEpisodeList
            }
        }
    }
    
    @ViewBuilder
    private var flatEpisodeList: some View {
        LazyVStack(spacing: 15) {
            ForEach(episodeLinks.indices.filter { selectedRange.contains($0) }, id: \.self) { i in
                let ep = episodeLinks[i]
                let lastPlayedTime = UserDefaults.standard.double(forKey: "lastPlayedTime_\(ep.href)")
                let totalTime = UserDefaults.standard.double(forKey: "totalTime_\(ep.href)")
                let progress = totalTime > 0 ? lastPlayedTime / totalTime : 0
                
                let defaultBannerImageValue = getBannerImageBasedOnAppearance()
                
                EpisodeCell(
                    episodeIndex: i,
                    episode: ep.href,
                    episodeID: ep.number - 1,
                    progress: progress,
                    itemID: itemID ?? 0,
                    totalEpisodes: episodeLinks.count,
                    defaultBannerImage: defaultBannerImageValue,
                    module: module,
                    parentTitle: title,
                    showPosterURL: imageUrl,
                    isMultiSelectMode: isMultiSelectMode,
                    isSelected: selectedEpisodes.contains(ep.number),
                    onSelectionChanged: { isSelected in
                        if isSelected {
                            selectedEpisodes.insert(ep.number)
                        } else {
                            selectedEpisodes.remove(ep.number)
                        }
                    },
                    onTap: { imageUrl in
                        episodeTapAction(ep: ep, imageUrl: imageUrl)
                    },
                    onMarkAllPrevious: {
                        markAllPreviousEpisodesInFlatList(ep: ep, index: i)
                    },
                    tmdbID: tmdbID,
                    seasonNumber: 1
                )
                    .disabled(isFetchingEpisode)
            }
        }
    }
    
    @ViewBuilder
    private var seasonsEpisodeList: some View {
        let seasons = groupedEpisodes()
        if !seasons.isEmpty, selectedSeason < seasons.count {
            LazyVStack(spacing: 15) {
                ForEach(seasons[selectedSeason]) { ep in
                    let lastPlayedTime = UserDefaults.standard.double(forKey: "lastPlayedTime_\(ep.href)")
                    let totalTime = UserDefaults.standard.double(forKey: "totalTime_\(ep.href)")
                    let progress = totalTime > 0 ? lastPlayedTime / totalTime : 0
                    
                    let defaultBannerImageValue = getBannerImageBasedOnAppearance()
                    
                    EpisodeCell(
                        episodeIndex: selectedSeason,
                        episode: ep.href,
                        episodeID: ep.number - 1,
                        progress: progress,
                        itemID: itemID ?? 0,
                        totalEpisodes: episodeLinks.count,
                        defaultBannerImage: defaultBannerImageValue,
                        module: module,
                        parentTitle: title,
                        showPosterURL: imageUrl,
                        isMultiSelectMode: isMultiSelectMode,
                        isSelected: selectedEpisodes.contains(ep.number),
                        onSelectionChanged: { isSelected in
                            if isSelected {
                                selectedEpisodes.insert(ep.number)
                            } else {
                                selectedEpisodes.remove(ep.number)
                            }
                        },
                        onTap: { imageUrl in
                            episodeTapAction(ep: ep, imageUrl: imageUrl)
                        },
                        onMarkAllPrevious: {
                            markAllPreviousEpisodesAsWatched(ep: ep, inSeason: true)
                        },
                        tmdbID: tmdbID,
                        seasonNumber: selectedSeason + 1
                    )
                        .disabled(isFetchingEpisode)
                }
            }
        } else {
            Text("No episodes available")
        }
    }
    
    private func restoreSelectionState() {
        if let savedStart = UserDefaults.standard.object(forKey: selectedRangeKey) as? Int,
           let savedRange = generateRanges().first(where: { $0.lowerBound == savedStart }) {
            selectedRange = savedRange
        } else {
            selectedRange = generateRanges().first ?? 0..<episodeChunkSize
        }

        if let savedSeason = UserDefaults.standard.object(forKey: selectedSeasonKey) as? Int {
            let maxIndex = max(0, groupedEpisodes().count - 1)
            selectedSeason = min(savedSeason, maxIndex)
        }
    }
    
    private func getBannerImageBasedOnAppearance() -> String {
        let isLightMode = selectedAppearance == .light || (selectedAppearance == .system && colorScheme == .light)
        return isLightMode
        ? "https://raw.githubusercontent.com/cranci1/Sora/refs/heads/dev/assets/banner1.png"
        : "https://raw.githubusercontent.com/cranci1/Sora/refs/heads/dev/assets/banner2.png"
    }
    
    private func episodeTapAction(ep: EpisodeLink, imageUrl: String) {
        if !isFetchingEpisode {
            selectedEpisodeNumber = ep.number
            selectedEpisodeImage = imageUrl
            fetchStream(href: ep.href)
            AnalyticsManager.shared.sendEvent(
                event: "watch",
                additionalData: ["title": title, "episode": ep.number]
            )
        }
    }
    
    private func fetchMetadataIDIfNeeded() {
        let provider = UserDefaults.standard.string(forKey: "metadataProviders") ?? "TMDB"
        let cleaned = cleanTitle(title)
        
        if provider == "TMDB" {
            tmdbID = nil
            tmdbFetcher.fetchBestMatchID(for: cleaned) { id, type in
                DispatchQueue.main.async {
                    self.tmdbID = id
                    self.tmdbType = type
                    Logger.shared.log("Fetched TMDB ID: \(id ?? -1) (\(type?.rawValue ?? "unknown")) for title: \(cleaned)", type: "Debug")
                }
            }
        } else if provider == "Anilist" {
            itemID = nil
            fetchItemID(byTitle: cleaned) { result in
                switch result {
                case .success(let id):
                    DispatchQueue.main.async {
                        self.itemID = id
                        Logger.shared.log("Fetched AniList ID: \(id) for title: \(cleaned)", type: "Debug")
                    }
                case .failure(let error):
                    Logger.shared.log("Failed to fetch AniList ID: \(error)", type: "Error")
                }
            }
        }
    }
    
    private func fetchTMDBPosterImageAndSet() {
        guard let tmdbID = tmdbID, let tmdbType = tmdbType else { return }
        let apiType = tmdbType.rawValue
        let urlString = "https://api.themoviedb.org/3/\(apiType)/\(tmdbID)?api_key=738b4edd0a156cc126dc4a4b8aea4aca"
        guard let url = URL(string: urlString) else { return }
        
        let tmdbImageWidth = UserDefaults.standard.string(forKey: "tmdbImageWidth") ?? "original"
        
        URLSession.custom.dataTask(with: url) { data, _, error in
            guard let data = data, error == nil else { return }
            do {
                if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let posterPath = json["poster_path"] as? String {
                    let imageUrl: String
                    if tmdbImageWidth == "original" {
                        imageUrl = "https://image.tmdb.org/t/p/original\(posterPath)"
                    } else {
                        imageUrl = "https://image.tmdb.org/t/p/w\(tmdbImageWidth)\(posterPath)"
                    }
                    DispatchQueue.main.async {
                        self.imageUrl = imageUrl
                        UserDefaults.standard.set(imageUrl, forKey: "tmdbPosterURL_\(self.href)")
                    }
                }
            } catch {
                Logger.shared.log("Failed to parse TMDB poster: \(error.localizedDescription)", type: "Error")
            }
        }.resume()
    }
    
    private func markAllPreviousEpisodesAsWatched(ep: EpisodeLink, inSeason: Bool) {
        let userDefaults = UserDefaults.standard
        var updates = [String: Double]()
        
        if inSeason {
            let seasons = groupedEpisodes()
            for ep2 in seasons[selectedSeason] where ep2.number < ep.number {
                let href = ep2.href
                updates["lastPlayedTime_\(href)"] = 99999999.0
                updates["totalTime_\(href)"] = 99999999.0
            }
            
            for (key, value) in updates {
                userDefaults.set(value, forKey: key)
            }
            
            userDefaults.synchronize()
            Logger.shared.log("Marked episodes watched within season \(selectedSeason + 1) of \"\(title)\".", type: "General")
        }
    }
    
    private func markAllPreviousEpisodesInFlatList(ep: EpisodeLink, index: Int) {
        let userDefaults = UserDefaults.standard
        var updates = [String: Double]()
        
        for idx in 0..<index {
            let href = episodeLinks[idx].href
            updates["lastPlayedTime_\(href)"] = 1000.0
            updates["totalTime_\(href)"] = 1000.0
        }
        for (key, value) in updates {
            userDefaults.set(value, forKey: key)
        }
        userDefaults.synchronize()
        NotificationCenter.default.post(name: NSNotification.Name("episodeProgressChanged"), object: nil)
        
        Logger.shared.log(
            "Marked \(ep.number - 1) episodes watched within series \"\(title)\".",
            type: "General"
        )
        
        guard let listID = itemID, listID > 0 else { return }
        let watchedCount = ep.number - 1
        let statusToSend = (watchedCount == episodeLinks.count) ? "COMPLETED" : "CURRENT"
        AniListMutation().updateAnimeProgress(
            animeId: listID,
            episodeNumber: watchedCount,
            status: statusToSend
        ) { result in
            switch result {
            case .success:
                Logger.shared.log(
                    "AniList bulk‐sync: set progress to \(watchedCount) (\(statusToSend))",
                    type: "General"
                )
            case .failure(let error):
                Logger.shared.log(
                    "AniList bulk‐sync failed: \(error.localizedDescription)",
                    type: "Error"
                )
            }
        }
    }
    
    @ViewBuilder
    private var noEpisodesSection: some View {
        VStack(spacing: 8) {
            Image(systemName: "tv.slash")
                .font(.system(size: 48))
                .foregroundColor(.secondary)
            
            Text("No Episodes Available")
                .font(.title2)
                .fontWeight(.semibold)
                .foregroundColor(.primary)
            
            Text("Episodes might not be available yet or there could be an issue with the source.")
                .font(.body)
                .lineLimit(0)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        }
        .padding(.vertical, 50)
    }
    
    private var startWatchingText: String {
        let indices = finishedAndUnfinishedIndices()
        let finished = indices.finished
        let unfinished = indices.unfinished
        
        if episodeLinks.count == 1 {
            if let unfinishedIndex = unfinished {
                return "Continue Watching"
            }
            return "Start Watching"
        }
        
        if let finishedIndex = finished, finishedIndex < episodeLinks.count - 1 {
            let nextEp = episodeLinks[finishedIndex + 1]
            return "Start Watching Episode \(nextEp.number)"
        }
        
        if let unfinishedIndex = unfinished {
            let currentEp = episodeLinks[unfinishedIndex]
            return "Continue Watching Episode \(currentEp.number)"
        }
        
        return "Start Watching"
    }
    
    private func playFirstUnwatchedEpisode() {
        let indices = finishedAndUnfinishedIndices()
        let finished = indices.finished
        let unfinished = indices.unfinished
        
        if let finishedIndex = finished, finishedIndex < episodeLinks.count - 1 {
            let nextEp = episodeLinks[finishedIndex + 1]
            selectedEpisodeNumber = nextEp.number
            fetchStream(href: nextEp.href)
            return
        }
        
        if let unfinishedIndex = unfinished {
            let ep = episodeLinks[unfinishedIndex]
            selectedEpisodeNumber = ep.number
            fetchStream(href: ep.href)
            return
        }
        
        if let firstEpisode = episodeLinks.first {
            selectedEpisodeNumber = firstEpisode.number
            fetchStream(href: firstEpisode.href)
        }
    }
    
    private func finishedAndUnfinishedIndices() -> (finished: Int?, unfinished: Int?) {
        var finishedIndex: Int? = nil
        var firstUnfinishedIndex: Int? = nil
        
        for (index, ep) in episodeLinks.enumerated() {
            let keyLast = "lastPlayedTime_\(ep.href)"
            let keyTotal = "totalTime_\(ep.href)"
            let lastPlayedTime = UserDefaults.standard.double(forKey: keyLast)
            let totalTime = UserDefaults.standard.double(forKey: keyTotal)
            
            guard totalTime > 0 else { continue }
            
            let remainingFraction = (totalTime - lastPlayedTime) / totalTime
            if remainingFraction <= 0.1 {
                finishedIndex = index
            } else if firstUnfinishedIndex == nil {
                firstUnfinishedIndex = index
            }
        }
        return (finishedIndex, firstUnfinishedIndex)
    }
    
    private func generateRanges() -> [Range<Int>] {
        let chunkSize = episodeChunkSize
        let totalEpisodes = episodeLinks.count
        var ranges: [Range<Int>] = []
        
        for i in stride(from: 0, to: totalEpisodes, by: chunkSize) {
            let end = min(i + chunkSize, totalEpisodes)
            ranges.append(i..<end)
        }
        
        return ranges
    }
    
    private func groupedEpisodes() -> [[EpisodeLink]] {
        guard !episodeLinks.isEmpty else { return [] }
        var groups: [[EpisodeLink]] = []
        var currentGroup: [EpisodeLink] = [episodeLinks[0]]
        
        for ep in episodeLinks.dropFirst() {
            if let last = currentGroup.last, ep.number < last.number {
                groups.append(currentGroup)
                currentGroup = [ep]
            } else {
                currentGroup.append(ep)
            }
        }
        
        groups.append(currentGroup)
        return groups
    }
    
    func fetchDetails() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            Task {
                do {
                    let jsContent = try moduleManager.getModuleContent(module)
                    jsController.loadScript(jsContent)
                    if module.metadata.asyncJS == true {
                        jsController.fetchDetailsJS(url: href) { items, episodes in
                            if let item = items.first {
                                self.synopsis = item.description
                                self.aliases = item.aliases
                                self.airdate = item.airdate
                            }
                            self.episodeLinks = episodes
                            self.restoreSelectionState()
                            self.isLoading = false
                            self.isRefetching = false
                        }
                    } else {
                        jsController.fetchDetails(url: href) { items, episodes in
                            if let item = items.first {
                                self.synopsis = item.description
                                self.aliases = item.aliases
                                self.airdate = item.airdate
                            }
                            self.episodeLinks = episodes
                            self.restoreSelectionState()
                            self.isLoading = false
                            self.isRefetching = false
                        }
                    }
                } catch {
                    Logger.shared.log("Error loading module: \(error)", type: "Error")
                    self.isLoading = false
                    self.isRefetching = false
                }
            }
        }
    }
    
    func fetchStream(href: String) {
        let fetchID = UUID()
        activeFetchID = fetchID
        currentStreamTitle = "Episode \(selectedEpisodeNumber)"
        showLoadingAlert = true
        isFetchingEpisode = true
        
        let completion: ((streams: [String]?, subtitles: [String]?, sources: [[String: Any]]?)) -> Void = { result in
            guard self.activeFetchID == fetchID else {
                return
            }
            
            self.showLoadingAlert = false
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                guard self.activeFetchID == fetchID else {
                    return
                }
                
                if let sources = result.sources, !sources.isEmpty {
                    if sources.count > 1 {
                        self.showStreamSelectionAlert(sources: sources, fullURL: href, subtitles: result.subtitles?.first, fetchID: fetchID)
                    } else if let streamUrl = sources[0]["streamUrl"] as? String {
                        let headers = sources[0]["headers"] as? [String: String]
                        self.playStream(url: streamUrl, fullURL: href, subtitles: result.subtitles?.first, headers: headers, fetchID: fetchID)
                    } else {
                        self.handleStreamFailure(error: nil)
                    }
                } else if let streams = result.streams, !streams.isEmpty {
                    if streams.count > 1 {
                        self.showStreamSelectionAlert(sources: streams, fullURL: href, subtitles: result.subtitles?.first, fetchID: fetchID)
                    } else {
                        self.playStream(url: streams[0], fullURL: href, subtitles: result.subtitles?.first, fetchID: fetchID)
                    }
                } else {
                    self.handleStreamFailure(error: nil)
                }
                
                DispatchQueue.main.async {
                    self.isFetchingEpisode = false
                }
            }
        }
        
        Task {
            do {
                let jsContent = try moduleManager.getModuleContent(module)
                jsController.loadScript(jsContent)
                
                if module.metadata.asyncJS == true {
                    jsController.fetchStreamUrlJS(episodeUrl: href, softsub: module.metadata.softsub == true, module: module, completion: completion)
                } else if module.metadata.streamAsyncJS == true {
                    jsController.fetchStreamUrlJSSecond(episodeUrl: href, softsub: module.metadata.softsub == true, module: module, completion: completion)
                } else {
                    jsController.fetchStreamUrl(episodeUrl: href, softsub: module.metadata.softsub == true, module: module, completion: completion)
                }
            } catch {
                self.handleStreamFailure(error: error)
                DispatchQueue.main.async {
                    self.isFetchingEpisode = false
                }
            }
        }
    }
    
    private func handleStreamFailure(error: Error?) {
        DispatchQueue.main.async {
            self.showLoadingAlert = false
            if let error = error {
                Logger.shared.log("Error loading module: \(error)", type: "Error")
                AnalyticsManager.shared.sendEvent(event: "error", additionalData: ["error": error, "message": "Failed to fetch stream"])
            }
            DropManager.shared.showDrop(title: "Stream not Found", subtitle: "", duration: 0.5, icon: UIImage(systemName: "xmark"))
            
            UINotificationFeedbackGenerator().notificationOccurred(.error)
            self.isLoading = false
        }
    }
    
    func showStreamSelectionAlert(sources: [Any], fullURL: String, subtitles: String? = nil, fetchID: UUID) {
        guard self.activeFetchID == fetchID else {
            return
        }
        
        self.isFetchingEpisode = false
        self.showLoadingAlert = false
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            guard self.activeFetchID == fetchID else {
                return
            }
            
            let alert = UIAlertController(title: "Select Server", message: "Choose a server to play from", preferredStyle: .actionSheet)
            
            var index = 0
            var streamIndex = 1
            
            while index < sources.count {
                var title: String = ""
                var streamUrl: String = ""
                var headers: [String:String]? = nil
                if let sources = sources as? [String] {
                    if index + 1 < sources.count {
                        if !sources[index].lowercased().contains("http") {
                            title = sources[index]
                            streamUrl = sources[index + 1]
                            index += 2
                        } else {
                            title = "Stream \(streamIndex)"
                            streamUrl = sources[index]
                            index += 1
                        }
                    } else {
                        title = "Stream \(streamIndex)"
                        streamUrl = sources[index]
                        index += 1
                    }
                }
                else if let sources = sources as? [[String: Any]] {
                    if let currTitle = sources[index]["title"] as? String {
                        title = currTitle
                        streamUrl = (sources[index]["streamUrl"] as? String) ?? ""
                    } else
                    {
                        title = "Stream \(streamIndex)"
                        streamUrl = (sources[index]["streamUrl"] as? String)!
                    }
                    headers = sources[index]["headers"] as? [String:String] ?? [:]
                    index += 1
                }
                
                
                alert.addAction(UIAlertAction(title: title, style: .default) { _ in
                    guard self.activeFetchID == fetchID else {
                        return
                    }
                    self.playStream(url: streamUrl, fullURL: fullURL, subtitles: subtitles, headers: headers, fetchID: fetchID)
                })
                
                streamIndex += 1
            }
            
            alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
            
            if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
               let window = windowScene.windows.first,
               let rootVC = window.rootViewController {
                
                if UIDevice.current.userInterfaceIdiom == .pad {
                    if let popover = alert.popoverPresentationController {
                        popover.sourceView = window
                        popover.sourceRect = CGRect(
                            x: UIScreen.main.bounds.width / 2,
                            y: UIScreen.main.bounds.height / 2,
                            width: 0,
                            height: 0
                        )
                        popover.permittedArrowDirections = []
                    }
                }
                
                findTopViewController.findViewController(rootVC).present(alert, animated: true)
            }
            
            DispatchQueue.main.async {
                self.isFetchingEpisode = false
            }
        }
    }
    
    func playStream(url: String, fullURL: String, subtitles: String? = nil, headers: [String:String]? = nil, fetchID: UUID) {
        guard self.activeFetchID == fetchID else {
            return
        }
        
        self.isFetchingEpisode = false
        self.showLoadingAlert = false
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            guard self.activeFetchID == fetchID else {
                return
            }
            
            let externalPlayer = UserDefaults.standard.string(forKey: "externalPlayer") ?? "Sora"
            var scheme: String?
            
            switch externalPlayer {
            case "Infuse":
                scheme = "infuse://x-callback-url/play?url=\(url)"
            case "VLC":
                scheme = "vlc://\(url)"
            case "OutPlayer":
                scheme = "outplayer://\(url)"
            case "nPlayer":
                scheme = "nplayer-\(url)"
            case "SenPlayer":
                scheme = "senplayer://x-callback-url/play?url=\(url)"
            case "IINA":
                scheme = "iina://weblink?url=\(url)"
            case "TracyPlayer":
                scheme = "tracy://open?url=\(url)"
            case "Default":
                let videoPlayerViewController = VideoPlayerViewController(module: module)
                videoPlayerViewController.headers = headers
                videoPlayerViewController.streamUrl = url
                videoPlayerViewController.fullUrl = fullURL
                videoPlayerViewController.episodeNumber = selectedEpisodeNumber
                videoPlayerViewController.episodeImageUrl = selectedEpisodeImage
                videoPlayerViewController.mediaTitle = title
                videoPlayerViewController.subtitles = subtitles ?? ""
                videoPlayerViewController.aniListID = itemID ?? 0
                videoPlayerViewController.modalPresentationStyle = .fullScreen
                
                if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                   let rootVC = windowScene.windows.first?.rootViewController {
                    findTopViewController.findViewController(rootVC).present(videoPlayerViewController, animated: true, completion: nil)
                } else {
                    Logger.shared.log("Failed to find root view controller", type: "Error")
                    DropManager.shared.showDrop(title: "Error", subtitle: "Failed to present player", duration: 2.0, icon: UIImage(systemName: "xmark.circle"))
                }
                
                return
            default:
                break
            }
            
            if let scheme = scheme, let url = URL(string: scheme), UIApplication.shared.canOpenURL(url) {
                UIApplication.shared.open(url, options: [:], completionHandler: nil)
                Logger.shared.log("Opening external app with scheme: \(url)", type: "General")
            } else {
                guard let url = URL(string: url) else {
                    Logger.shared.log("Invalid stream URL: \(url)", type: "Error")
                    DropManager.shared.showDrop(title: "Error", subtitle: "Invalid stream URL", duration: 2.0, icon: UIImage(systemName: "xmark.circle"))
                    return
                }
                
                guard self.activeFetchID == fetchID else {
                    return
                }
                
                let customMediaPlayer = CustomMediaPlayerViewController(
                    module: module,
                    urlString: url.absoluteString,
                    fullUrl: fullURL,
                    title: title,
                    episodeNumber: selectedEpisodeNumber,
                    onWatchNext: {
                        selectNextEpisode()
                    },
                    subtitlesURL: subtitles,
                    aniListID: itemID ?? 0,
                    totalEpisodes: episodeLinks.count,
                    episodeImageUrl: selectedEpisodeImage,
                    headers: headers ?? nil
                )
                customMediaPlayer.modalPresentationStyle = .fullScreen
                Logger.shared.log("Opening custom media player with url: \(url)")
                
                if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                   let rootVC = windowScene.windows.first?.rootViewController {
                    findTopViewController.findViewController(rootVC).present(customMediaPlayer, animated: true, completion: nil)
                } else {
                    Logger.shared.log("Failed to find root view controller", type: "Error")
                    DropManager.shared.showDrop(title: "Error", subtitle: "Failed to present player", duration: 2.0, icon: UIImage(systemName: "xmark.circle"))
                }
            }
        }
    }
    
    private func selectNextEpisode() {
        guard let currentIndex = episodeLinks.firstIndex(where: { $0.number == selectedEpisodeNumber }),
              currentIndex + 1 < episodeLinks.count else {
                  Logger.shared.log("No more episodes to play", type: "Info")
                  return
              }
        
        let nextEpisode = episodeLinks[currentIndex + 1]
        selectedEpisodeNumber = nextEpisode.number
        fetchStream(href: nextEpisode.href)
        DropManager.shared.showDrop(title: "Fetching Next Episode", subtitle: "", duration: 0.5, icon: UIImage(systemName: "arrow.triangle.2.circlepath"))
    }
    
    private func openSafariViewController(with urlString: String) {
        guard let url = URL(string: urlString), UIApplication.shared.canOpenURL(url) else {
            Logger.shared.log("Unable to open the webpage", type: "Error")
            return
        }
        let safariViewController = SFSafariViewController(url: url)
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let rootVC = windowScene.windows.first?.rootViewController {
            rootVC.present(safariViewController, animated: true, completion: nil)
        }
    }
    
    private func cleanTitle(_ title: String?) -> String {
        guard let title = title else { return "Unknown" }
        
        let cleaned = title.replacingOccurrences(
            of: "\\s*\\([^\\)]*\\)",
            with: "",
            options: .regularExpression
        ).trimmingCharacters(in: .whitespaces)
        
        return cleaned.isEmpty ? "Unknown" : cleaned
    }
    
    private func fetchItemID(byTitle title: String, completion: @escaping (Result<Int, Error>) -> Void) {
        let query = """
        query {
            Media(search: "\(title)", type: ANIME) {
                id
            }
        }
        """
        
        guard let url = URL(string: "https://graphql.anilist.co") else {
            completion(.failure(NSError(domain: "", code: 0, userInfo: [NSLocalizedDescriptionKey: "Invalid URL"])))
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let parameters: [String: Any] = ["query": query]
        request.httpBody = try? JSONSerialization.data(withJSONObject: parameters)
        
        URLSession.custom.dataTask(with: request) { data, _, error in
            if let error = error {
                completion(.failure(error))
                return
            }
            
            guard let data = data else {
                completion(.failure(NSError(domain: "", code: 0, userInfo: [NSLocalizedDescriptionKey: "No data received"])))
                return
            }
            
            do {
                if let json = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any],
                   let data = json["data"] as? [String: Any],
                   let media = data["Media"] as? [String: Any],
                   let id = media["id"] as? Int {
                    completion(.success(id))
                } else {
                    let error = NSError(domain: "", code: 0, userInfo: [NSLocalizedDescriptionKey: "Invalid response"])
                    completion(.failure(error))
                }
            } catch {
                completion(.failure(error))
            }
        }.resume()
    }
    
    private func showCustomIDAlert() {
        let alert = UIAlertController(title: "Set Custom AniList ID", message: "Enter the AniList ID for this media", preferredStyle: .alert)
        
        alert.addTextField { textField in
            textField.placeholder = "AniList ID"
            textField.keyboardType = .numberPad
            if let customID = customAniListID {
                textField.text = "\(customID)"
            }
        }
        
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        alert.addAction(UIAlertAction(title: "Save", style: .default) { _ in
            if let text = alert.textFields?.first?.text,
               let id = Int(text) {
                customAniListID = id
                itemID = id
                UserDefaults.standard.set(id, forKey: "custom_anilist_id_\(href)")
                Logger.shared.log("Set custom AniList ID: \(id)", type: "General")
                self.fetchDetails()
            }
        })
        
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let window = windowScene.windows.first,
           let rootVC = window.rootViewController {
            findTopViewController.findViewController(rootVC).present(alert, animated: true)
        }
    }
    
    private func selectEpisodeRange(start: Int, end: Int) {
        selectedEpisodes.removeAll()
        for episodeNumber in start...end {
            selectedEpisodes.insert(episodeNumber)
        }
        showRangeInput = false
    }
    
    private func selectAllVisibleEpisodes() {
        if isGroupedBySeasons {
            let seasons = groupedEpisodes()
            if !seasons.isEmpty, selectedSeason < seasons.count {
                for episode in seasons[selectedSeason] {
                    selectedEpisodes.insert(episode.number)
                }
            }
        } else {
            for i in episodeLinks.indices.filter({ selectedRange.contains($0) }) {
                selectedEpisodes.insert(episodeLinks[i].number)
            }
        }
    }
    
    private func startBulkDownload() {
        guard !selectedEpisodes.isEmpty else { return }
        
        isBulkDownloading = true
        bulkDownloadProgress = "Starting downloads..."
        let episodesToDownload = episodeLinks.filter { selectedEpisodes.contains($0.number) }
        
        Task {
            await processBulkDownload(episodes: episodesToDownload)
        }
    }
    
    @MainActor
    private func processBulkDownload(episodes: [EpisodeLink]) async {
        let totalCount = episodes.count
        var completedCount = 0
        var successCount = 0
        
        for (index, episode) in episodes.enumerated() {
            bulkDownloadProgress = "Downloading episode \(episode.number) (\(index + 1)/\(totalCount))"
            
            let downloadStatus = jsController.isEpisodeDownloadedOrInProgress(
                showTitle: title,
                episodeNumber: episode.number,
                season: 1
            )
            
            switch downloadStatus {
            case .downloaded:
                Logger.shared.log("Episode \(episode.number) already downloaded, skipping", type: "Info")
            case .downloading:
                Logger.shared.log("Episode \(episode.number) already downloading, skipping", type: "Info")
            case .notDownloaded:
                let downloadSuccess = await downloadSingleEpisode(episode: episode)
                if downloadSuccess {
                    successCount += 1
                }
            }
            
            completedCount += 1
            
            try? await Task.sleep(nanoseconds: 500_000_000)
        }
        
        isBulkDownloading = false
        bulkDownloadProgress = ""
        isMultiSelectMode = false
        selectedEpisodes.removeAll()
        
        DropManager.shared.showDrop(
            title: "Bulk Download Complete",
            subtitle: "\(successCount)/\(totalCount) episodes queued for download",
            duration: 2.0,
            icon: UIImage(systemName: successCount == totalCount ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
        )
    }
    
    private func downloadSingleEpisode(episode: EpisodeLink) async -> Bool {
        return await withCheckedContinuation { continuation in
            Task {
                do {
                    let jsContent = try moduleManager.getModuleContent(module)
                    jsController.loadScript(jsContent)
                    
                    self.tryNextDownloadMethodForBulk(
                        episode: episode,
                        methodIndex: 0,
                        softsub: module.metadata.softsub == true,
                        continuation: continuation
                    )
                } catch {
                    Logger.shared.log("Error downloading episode \(episode.number): \(error)", type: "Error")
                    continuation.resume(returning: false)
                }
            }
        }
    }
    
    private func tryNextDownloadMethodForBulk(
        episode: EpisodeLink,
        methodIndex: Int,
        softsub: Bool,
        continuation: CheckedContinuation<Bool, Never>
    ) {
        print("[Bulk Download] Trying download method #\(methodIndex+1) for Episode \(episode.number)")
        
        switch methodIndex {
        case 0:
            if module.metadata.asyncJS == true {
                jsController.fetchStreamUrlJS(episodeUrl: episode.href, softsub: softsub, module: module) { result in
                    self.handleBulkDownloadResult(result, episode: episode, methodIndex: methodIndex, softsub: softsub, continuation: continuation)
                }
            } else {
                tryNextDownloadMethodForBulk(episode: episode, methodIndex: methodIndex + 1, softsub: softsub, continuation: continuation)
            }
            
        case 1:
            if module.metadata.streamAsyncJS == true {
                jsController.fetchStreamUrlJSSecond(episodeUrl: episode.href, softsub: softsub, module: module) { result in
                    self.handleBulkDownloadResult(result, episode: episode, methodIndex: methodIndex, softsub: softsub, continuation: continuation)
                }
            } else {
                tryNextDownloadMethodForBulk(episode: episode, methodIndex: methodIndex + 1, softsub: softsub, continuation: continuation)
            }
            
        case 2:
            jsController.fetchStreamUrl(episodeUrl: episode.href, softsub: softsub, module: module) { result in
                self.handleBulkDownloadResult(result, episode: episode, methodIndex: methodIndex, softsub: softsub, continuation: continuation)
            }
            
        default:
            Logger.shared.log("Failed to find a valid stream for bulk download after trying all methods", type: "Error")
            continuation.resume(returning: false)
        }
    }
    
    private func handleBulkDownloadResult(_ result: (streams: [String]?, subtitles: [String]?, sources: [[String:Any]]?), episode: EpisodeLink, methodIndex: Int, softsub: Bool, continuation: CheckedContinuation<Bool, Never>) {
        
        if let sources = result.sources, !sources.isEmpty {
            if sources.count > 1 {
                showBulkDownloadStreamSelectionAlert(sources: sources, episode: episode, continuation: continuation)
                return
            } else if let streamUrl = sources[0]["streamUrl"] as? String, let url = URL(string: streamUrl) {
                
                let subtitleURLString = sources[0]["subtitle"] as? String
                let subtitleURL = subtitleURLString.flatMap { URL(string: $0) }
                if let subtitleURL = subtitleURL {
                    Logger.shared.log("[Bulk Download] Found subtitle URL: \(subtitleURL.absoluteString)")
                }
                
                startEpisodeDownloadWithProcessedStream(episode: episode, url: url, streamUrl: streamUrl, subtitleURL: subtitleURL)
                continuation.resume(returning: true)
                return
            }
        }
        
        if let streams = result.streams, !streams.isEmpty {
            if streams[0] == "[object Promise]" {
                tryNextDownloadMethodForBulk(episode: episode, methodIndex: methodIndex + 1, softsub: softsub, continuation: continuation)
                return
            }
            
            if streams.count > 1 {
                showBulkDownloadStreamSelectionAlert(sources: streams, episode: episode, continuation: continuation)
                return
            } else if let url = URL(string: streams[0]) {
                let subtitleURL = result.subtitles?.first.flatMap { URL(string: $0) }
                if let subtitleURL = subtitleURL {
                    Logger.shared.log("[Bulk Download] Found subtitle URL: \(subtitleURL.absoluteString)")
                }
                
                startEpisodeDownloadWithProcessedStream(episode: episode, url: url, streamUrl: streams[0], subtitleURL: subtitleURL)
                continuation.resume(returning: true)
                return
            }
        }
        
        tryNextDownloadMethodForBulk(episode: episode, methodIndex: methodIndex + 1, softsub: softsub, continuation: continuation)
    }
    
    private func showBulkDownloadStreamSelectionAlert(sources: [Any], episode: EpisodeLink, continuation: CheckedContinuation<Bool, Never>) {
        DispatchQueue.main.async {
            let alert = UIAlertController(title: "Select Download Server", message: "Choose a server to download Episode \(episode.number) from", preferredStyle: .actionSheet)
            
            var index = 0
            var streamIndex = 1
            
            while index < sources.count {
                var title: String = ""
                var streamUrl: String = ""
                var headers: [String:String]? = nil
                
                if let sources = sources as? [String] {
                    if index + 1 < sources.count {
                        if !sources[index].lowercased().contains("http") {
                            title = sources[index]
                            streamUrl = sources[index + 1]
                            index += 2
                        } else {
                            title = "Server \(streamIndex)"
                            streamUrl = sources[index]
                            index += 1
                        }
                    } else {
                        title = "Server \(streamIndex)"
                        streamUrl = sources[index]
                        index += 1
                    }
                } else if let sources = sources as? [[String: Any]] {
                    if let currTitle = sources[index]["title"] as? String {
                        title = currTitle
                    } else {
                        title = "Server \(streamIndex)"
                    }
                    streamUrl = (sources[index]["streamUrl"] as? String) ?? ""
                    index += 1
                }
                
                alert.addAction(UIAlertAction(title: title, style: .default) { _ in
                    guard let url = URL(string: streamUrl) else {
                        DropManager.shared.error("Invalid stream URL selected")
                        continuation.resume(returning: false)
                        return
                    }
                    
                    var subtitleURL: URL? = nil
                    if let sources = sources as? [[String: Any]],
                       let subtitleURLString = sources[index-1]["subtitle"] as? String {
                        subtitleURL = URL(string: subtitleURLString)
                    }
                    
                    self.startEpisodeDownloadWithProcessedStream(episode: episode, url: url, streamUrl: streamUrl, subtitleURL: subtitleURL)
                    continuation.resume(returning: true)
                })
                
                streamIndex += 1
            }
            
            alert.addAction(UIAlertAction(title: "Cancel", style: .cancel) { _ in
                continuation.resume(returning: false)
            })
            
            if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
               let window = windowScene.windows.first,
               let rootVC = window.rootViewController {
                
                if UIDevice.current.userInterfaceIdiom == .pad {
                    if let popover = alert.popoverPresentationController {
                        popover.sourceView = window
                        popover.sourceRect = CGRect(
                            x: UIScreen.main.bounds.width / 2,
                            y: UIScreen.main.bounds.height / 2,
                            width: 0,
                            height: 0
                        )
                        popover.permittedArrowDirections = []
                    }
                }
                
                findTopViewController.findViewController(rootVC).present(alert, animated: true)
            }
        }
    }
    
    private func startEpisodeDownloadWithProcessedStream(episode: EpisodeLink, url: URL, streamUrl: String, subtitleURL: URL? = nil) {
        var headers: [String: String] = [:]
        
        if !module.metadata.baseUrl.isEmpty && !module.metadata.baseUrl.contains("undefined") {
            print("Using module baseUrl: \(module.metadata.baseUrl)")
            
            headers = [
                "Origin": module.metadata.baseUrl,
                "Referer": module.metadata.baseUrl,
                "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/134.0.0.0 Safari/537.36",
                "Accept": "*/*",
                "Accept-Language": "en-US,en;q=0.9",
                "Sec-Fetch-Dest": "empty",
                "Sec-Fetch-Mode": "cors",
                "Sec-Fetch-Site": "same-origin"
            ]
        } else {
            if let scheme = url.scheme, let host = url.host {
                let baseUrl = scheme + "://" + host
                
                headers = [
                    "Origin": baseUrl,
                    "Referer": baseUrl,
                    "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/134.0.0.0 Safari/537.36",
                    "Accept": "*/*",
                    "Accept-Language": "en-US,en;q=0.9",
                    "Sec-Fetch-Dest": "empty",
                    "Sec-Fetch-Mode": "cors",
                    "Sec-Fetch-Site": "same-origin"
                ]
            } else {
                headers = [
                    "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/134.0.0.0 Safari/537.36"
                ]
                Logger.shared.log("Warning: Missing URL scheme/host for episode \(episode.number), using minimal headers", type: "Warning")
            }
        }
        
        print("Bulk download headers: \(headers)")
        fetchEpisodeMetadataForDownload(episode: episode) { metadata in
            let episodeTitle = metadata?.title["en"] ?? metadata?.title.values.first ?? ""
            let episodeImageUrl = metadata?.imageUrl ?? ""
            
            let episodeName = metadata?.title["en"] ?? "Episode \(episode.number)"
            let fullEpisodeTitle = episodeName
            
            let episodeThumbnailURL: URL?
            if !episodeImageUrl.isEmpty {
                episodeThumbnailURL = URL(string: episodeImageUrl)
            } else {
                episodeThumbnailURL = URL(string: self.getBannerImageBasedOnAppearance())
            }
            
            let showPosterImageURL = URL(string: self.imageUrl)
            
            print("[Bulk Download] Using episode metadata - Title: '\(fullEpisodeTitle)', Image: '\(episodeImageUrl.isEmpty ? "default banner" : episodeImageUrl)'")
            
            self.jsController.downloadWithStreamTypeSupport(
                url: url,
                headers: headers,
                title: fullEpisodeTitle,
                imageURL: episodeThumbnailURL,
                module: self.module,
                isEpisode: true,
                showTitle: self.title,
                season: 1,
                episode: episode.number,
                subtitleURL: subtitleURL,
                showPosterURL: showPosterImageURL,
                completionHandler: { success, message in
                    if success {
                        Logger.shared.log("Queued download for Episode \(episode.number) with metadata", type: "Download")
                    } else {
                        Logger.shared.log("Failed to queue download for Episode \(episode.number): \(message)", type: "Error")
                    }
                }
            )
        }
    }
    
    private func fetchEpisodeMetadataForDownload(episode: EpisodeLink, completion: @escaping (EpisodeMetadataInfo?) -> Void) {
        guard let anilistId = itemID else {
            Logger.shared.log("No AniList ID available for episode metadata", type: "Warning")
            completion(nil)
            return
        }
        
        fetchEpisodeMetadataFromNetwork(anilistId: anilistId, episodeNumber: episode.number, completion: completion)
    }
    
    private func fetchEpisodeMetadataFromNetwork(anilistId: Int, episodeNumber: Int, completion: @escaping (EpisodeMetadataInfo?) -> Void) {
        guard let url = URL(string: "https://api.ani.zip/mappings?anilist_id=\(anilistId)") else {
            Logger.shared.log("Invalid URL for anilistId: \(anilistId)", type: "Error")
            completion(nil)
            return
        }
        
        print("[Bulk Download] Fetching metadata for episode \(episodeNumber) from network")
        
        URLSession.custom.dataTask(with: url) { data, response, error in
            if let error = error {
                Logger.shared.log("Failed to fetch episode metadata: \(error)", type: "Error")
                completion(nil)
                return
            }
            
            guard let data = data else {
                Logger.shared.log("No data received for episode metadata", type: "Error")
                completion(nil)
                return
            }
            
            do {
                let jsonObject = try JSONSerialization.jsonObject(with: data, options: [])
                guard let json = jsonObject as? [String: Any] else {
                    Logger.shared.log("Invalid JSON format for episode metadata", type: "Error")
                    completion(nil)
                    return
                }
                
                guard let episodes = json["episodes"] as? [String: Any] else {
                    Logger.shared.log("Missing 'episodes' object in metadata response", type: "Error")
                    completion(nil)
                    return
                }
                
                let episodeKey = "\(episodeNumber)"
                guard let episodeDetails = episodes[episodeKey] as? [String: Any] else {
                    Logger.shared.log("Episode \(episodeKey) not found in metadata response", type: "Warning")
                    completion(nil)
                    return
                }
                
                var title: [String: String] = [:]
                var image: String = ""
                
                if let titleData = episodeDetails["title"] as? [String: String], !titleData.isEmpty {
                    title = titleData
                } else {
                    title = ["en": "Episode \(episodeNumber)"]
                }
                
                if let imageUrl = episodeDetails["image"] as? String, !imageUrl.isEmpty {
                    image = imageUrl
                }
                
                let metadataInfo = EpisodeMetadataInfo(
                    title: title,
                    imageUrl: image,
                    anilistId: anilistId,
                    episodeNumber: episodeNumber
                )
                
                print("[Bulk Download] Fetched metadata for episode \(episodeNumber): title='\(title["en"] ?? "N/A")', hasImage=\(!image.isEmpty)")
                completion(metadataInfo)
                
            } catch {
                Logger.shared.log("JSON parsing error for episode metadata: \(error.localizedDescription)", type: "Error")
                completion(nil)
            }
        }.resume()
    }
}
