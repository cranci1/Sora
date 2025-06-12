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
    
    @State private var aliases: String = ""
    @State private var synopsis: String = ""
    @State private var airdate: String = ""
    @State private var episodeLinks: [EpisodeLink] = []
    @State private var itemID: Int?
    @State private var tmdbID: Int?
    @State private var tmdbType: TMDBFetcher.MediaType? = nil
    @State private var currentFetchTask: Task<Void, Never>? = nil
    
    @State private var isLoading: Bool = true
    @State private var showFullSynopsis: Bool = false
    @State private var hasFetched: Bool = false
    @State private var isRefetching: Bool = true
    @State private var isFetchingEpisode: Bool = false
    @State private var isError = false
    @State private var showLoadingAlert: Bool = false
    
    @State private var selectedEpisodeNumber: Int = 0
    @State private var selectedEpisodeImage: String = ""
    @State private var selectedSeason: Int = 0
    @State private var selectedRange: Range<Int> = {
        let size = UserDefaults.standard.integer(forKey: "episodeChunkSize")
        let chunk = size == 0 ? 100 : size
        return 0..<chunk
    }()
    
    @State private var isMultiSelectMode: Bool = false
    @State private var selectedEpisodes: Set<Int> = []
    @State private var showRangeInput: Bool = false
    @State private var isBulkDownloading: Bool = false
    @State private var bulkDownloadProgress: String = ""
    @State private var isSingleEpisodeDownloading: Bool = false
    
    @State private var isModuleSelectorPresented = false
    @State private var isMatchingPresented = false
    @State private var matchedTitle: String? = nil
    @State private var showSettingsMenu = false
    @State private var customAniListID: Int?
    @State private var showStreamLoadingView: Bool = false
    @State private var currentStreamTitle: String = ""
    @State private var activeFetchID: UUID? = nil
    
    @State private var refreshTrigger: Bool = false
    @State private var buttonRefreshTrigger: Bool = false
    
    private var selectedRangeKey: String { "selectedRangeStart_\(href)" }
    private var selectedSeasonKey: String { "selectedSeason_\(href)" }
    
    @AppStorage("externalPlayer") private var externalPlayer: String = "Default"
    @AppStorage("episodeChunkSize") private var episodeChunkSize: Int = 100
    @AppStorage("selectedAppearance") private var selectedAppearance: Appearance = .system
    
    @ObservedObject private var jsController = JSController.shared
    @EnvironmentObject var moduleManager: ModuleManager
    @EnvironmentObject private var libraryManager: LibraryManager
    @EnvironmentObject var tabBarController: TabBarController
    
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.verticalSizeClass) private var verticalSizeClass
    
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
    
    private var startWatchingText: String {
        let indices = finishedAndUnfinishedIndices()
        let finished = indices.finished
        let unfinished = indices.unfinished
        
        if episodeLinks.count == 1 {
            if let _ = unfinished {
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
                setupViewOnAppear()
            }
            .onChange(of: selectedRange) { newValue in
                UserDefaults.standard.set(newValue.lowerBound, forKey: selectedRangeKey)
            }
            .onChange(of: selectedSeason) { newValue in
                UserDefaults.standard.set(newValue, forKey: selectedSeasonKey)
            }
            .onDisappear {
                tabBarController.showTabBar()
                currentFetchTask?.cancel()
                activeFetchID = nil
            }
            .task {
                await setupInitialData()
            }
            .alert("Loading Stream", isPresented: $showLoadingAlert) {
                Button("Cancel", role: .cancel) {
                    cancelCurrentFetch()
                }
            } message: {
                HStack {
                    Text("Loading Episode \(selectedEpisodeNumber)...")
                    ProgressView()
                        .padding(.top, 8)
                }
            }
            
            navigationOverlay
        }
    }
    
    @ViewBuilder
    private var navigationOverlay: some View {
        VStack {
            HStack {
                Button(action: { dismiss() }) {
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
    
    @ViewBuilder
    private var mainScrollView: some View {
        ScrollView {
            ZStack(alignment: .top) {
                heroImageSection
                contentContainer
            }
        }
        .onAppear {
            UIScrollView.appearance().bounces = false
        }
    }
    
    @ViewBuilder
    private var heroImageSection: some View {
        LazyImage(url: URL(string: imageUrl)) { state in
            if let uiImage = state.imageContainer?.image {
                Image(uiImage: uiImage)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: UIScreen.main.bounds.width, height: 700)
                    .clipped()
            } else {
                Rectangle()
                    .fill(
                        LinearGradient(
                            gradient: Gradient(colors: [
                                Color.gray.opacity(0.2),
                                Color.gray.opacity(0.3),
                                Color.gray.opacity(0.2)
                            ]),
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: UIScreen.main.bounds.width, height: 700)
                    .clipped()
            }
        }
    }
    
    @ViewBuilder
    private var contentContainer: some View {
        VStack(spacing: 0) {
            Rectangle()
                .fill(Color.clear)
                .frame(height: 400)
            
            ZStack(alignment: .top) {
                gradientOverlay
                
                VStack(alignment: .leading, spacing: 16) {
                    headerSection
                    if !episodeLinks.isEmpty {
                        episodesSection
                    } else {
                        noEpisodesSection
                    }
                }
                .padding()
            }
        }
    }
    
    @ViewBuilder
    private var gradientOverlay: some View {
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
        .frame(height: 300)
        .clipShape(RoundedRectangle(cornerRadius: 0))
        .shadow(color: (colorScheme == .dark ? Color.black : Color.white).opacity(1), radius: 10, x: 0, y: 10)
    }
    
    @ViewBuilder
    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            if !airdate.isEmpty && airdate != "N/A" && airdate != "No Data" {
                HStack(spacing: 4) {
                    Image(systemName: "calendar")
                        .foregroundColor(.accentColor)
                    Text(airdate)
                        .font(.system(size: 14))
                        .foregroundColor(.accentColor)
                    Spacer()
                }
            }
            
            Text(title)
                .font(.system(size: 28, weight: .bold))
                .foregroundColor(.primary)
                .lineLimit(3)
                .onLongPressGesture {
                    copyTitleToClipboard()
                }
            
            if !synopsis.isEmpty {
                synopsisSection
            }
            
            playAndBookmarkSection
            
            if episodeLinks.count == 1 {
                singleEpisodeSection
            }
        }
    }
    
    @ViewBuilder
    private var synopsisSection: some View {
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
    
    @ViewBuilder
    private var playAndBookmarkSection: some View {
        HStack(spacing: 12) {
            Button(action: { playFirstUnwatchedEpisode() }) {
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
            
            Button(action: { toggleBookmark() }) {
                Image(systemName: isBookmarked ? "bookmark.fill" : "bookmark")
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
    private var singleEpisodeSection: some View {
        VStack(spacing: 12) {
            HStack(spacing: 12) {
                Button(action: { toggleSingleEpisodeWatchStatus() }) {
                    HStack(spacing: 4) {
                        Image(systemName: singleEpisodeWatchIcon)
                            .foregroundColor(.primary)
                        Text(singleEpisodeWatchText)
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.primary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 6)
                    .background(Color.gray.opacity(0.2))
                    .cornerRadius(15)
                    .gradientOutline()
                }
                
                Button(action: { downloadSingleEpisode() }) {
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
            
            VStack(spacing: 4) {
                Text("Why am I not seeing any episodes?")
                    .font(.caption)
                    .bold()
                    .foregroundColor(.gray)
                    .frame(maxWidth: .infinity, alignment: .leading)
                
                Text("The module provided only a single episode, this is most likely a movie, so we decided to make separate screens for these cases.")
                    .font(.caption)
                    .foregroundColor(.gray)
                    .multilineTextAlignment(.leading)
                    .lineLimit(nil)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.top, 4)
        }
    }
    
    private var isBookmarked: Bool {
        libraryManager.isBookmarked(href: href, moduleName: module.metadata.sourceName)
    }
    
    private var singleEpisodeWatchIcon: String {
        if let ep = episodeLinks.first {
            let lastPlayedTime = UserDefaults.standard.double(forKey: "lastPlayedTime_\(ep.href)")
            let totalTime = UserDefaults.standard.double(forKey: "totalTime_\(ep.href)")
            let progress = totalTime > 0 ? lastPlayedTime / totalTime : 0
            return progress <= 0.9 ? "checkmark.circle" : "arrow.counterclockwise"
        }
        return "checkmark.circle"
    }
    
    private var singleEpisodeWatchText: String {
        if let ep = episodeLinks.first {
            let lastPlayedTime = UserDefaults.standard.double(forKey: "lastPlayedTime_\(ep.href)")
            let totalTime = UserDefaults.standard.double(forKey: "totalTime_\(ep.href)")
            let progress = totalTime > 0 ? lastPlayedTime / totalTime : 0
            return progress <= 0.9 ? "Mark watched" : "Reset progress"
        }
        return "Mark watched"
    }
    
    @ViewBuilder
    private var episodesSection: some View {
        if episodeLinks.count != 1 {
            VStack(alignment: .leading, spacing: 16) {
                episodesSectionHeader
                episodeListSection
            }
        }
    }
    
    @ViewBuilder
    private var episodesSectionHeader: some View {
        HStack {
            Text("Episodes")
                .font(.system(size: 22, weight: .bold))
                .foregroundColor(.primary)
            
            Spacer()
            
            episodeNavigationSection
            
            HStack(spacing: 4) {
                sourceButton
                menuButton
            }
        }
    }
    
    @ViewBuilder
    private var episodeNavigationSection: some View {
        Group {
            if !isGroupedBySeasons && episodeLinks.count <= episodeChunkSize {
                EmptyView()
            } else if !isGroupedBySeasons && episodeLinks.count > episodeChunkSize {
                rangeSelectionMenu
            } else if isGroupedBySeasons {
                seasonSelectionMenu
            }
        }
    }
    
    @ViewBuilder
    private var rangeSelectionMenu: some View {
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
    }
    
    @ViewBuilder
    private var seasonSelectionMenu: some View {
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
        VStack(spacing: 15) {
            ForEach(episodeLinks.indices.filter { selectedRange.contains($0) }, id: \.self) { i in
                let ep = episodeLinks[i]
                createEpisodeCell(episode: ep, index: i, season: 1)
            }
        }
    }
    
    @ViewBuilder
    private var seasonsEpisodeList: some View {
        let seasons = groupedEpisodes()
        if !seasons.isEmpty, selectedSeason < seasons.count {
            VStack(spacing: 15) {
                ForEach(seasons[selectedSeason]) { ep in
                    createEpisodeCell(episode: ep, index: selectedSeason, season: selectedSeason + 1)
                }
            }
        } else {
            Text("No episodes available")
        }
    }
    
    @ViewBuilder
    private func createEpisodeCell(episode: EpisodeLink, index: Int, season: Int) -> some View {
        let lastPlayedTime = UserDefaults.standard.double(forKey: "lastPlayedTime_\(episode.href)")
        let totalTime = UserDefaults.standard.double(forKey: "totalTime_\(episode.href)")
        let progress = totalTime > 0 ? lastPlayedTime / totalTime : 0
        let defaultBannerImageValue = getBannerImageBasedOnAppearance()
        
        EpisodeCell(
            episodeIndex: index,
            episode: episode.href,
            episodeID: episode.number - 1,
            progress: progress,
            itemID: itemID ?? 0,
            totalEpisodes: episodeLinks.count,
            defaultBannerImage: defaultBannerImageValue,
            module: module,
            parentTitle: title,
            showPosterURL: imageUrl,
            isMultiSelectMode: isMultiSelectMode,
            isSelected: selectedEpisodes.contains(episode.number),
            onSelectionChanged: { isSelected in
                handleEpisodeSelection(episode: episode, isSelected: isSelected)
            },
            onTap: { imageUrl in
                episodeTapAction(ep: episode, imageUrl: imageUrl)
            },
            onMarkAllPrevious: {
                markAllPreviousEpisodes(episode: episode, index: index, inSeason: isGroupedBySeasons)
            },
            tmdbID: tmdbID,
            seasonNumber: season
        )
        .disabled(isFetchingEpisode)
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
    
    @ViewBuilder
    private var sourceButton: some View {
        Button(action: { openSafariViewController(with: href) }) {
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
            menuContent
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
                handleAniListMatch(selectedID: selectedID)
            }
        }
    }
    
    @ViewBuilder
    private var menuContent: some View {
        Group {
            if let id = itemID ?? customAniListID {
                let labelText = (matchedTitle?.isEmpty == false ? matchedTitle! : "\(id)")
                Text("Matched with: \(labelText)")
                    .font(.caption)
                    .foregroundColor(.gray)
                    .padding(.vertical, 4)
            }
            
            Divider()
            
            if let _ = customAniListID {
                Button(action: { resetAniListID() }) {
                    Label("Reset AniList ID", systemImage: "arrow.clockwise")
                }
            }
            
            if let id = itemID ?? customAniListID {
                Button(action: { openAniListPage(id: id) }) {
                    Label("Open in AniList", systemImage: "link")
                }
            }
            
            if UserDefaults.standard.string(forKey: "metadataProviders") ?? "TMDB" == "AniList" {
                Button(action: { isMatchingPresented = true }) {
                    Label("Match with AniList", systemImage: "magnifyingglass")
                }
            }
            
            posterMenuOptions
            
            Divider()
            
            Button(action: { logDebugInfo() }) {
                Label("Log Debug Info", systemImage: "terminal")
            }
        }
    }
    
    @ViewBuilder
    private var posterMenuOptions: some View {
        Group {
            if UserDefaults.standard.string(forKey: "originalPoster_\(href)") != nil {
                Button(action: { restoreOriginalPoster() }) {
                    Label("Original Poster", systemImage: "photo.badge.arrow.down")
                }
            } else {
                Button(action: { fetchTMDBPosterImageAndSet() }) {
                    Label("Use TMDB Poster Image", systemImage: "photo")
                }
            }
        }
    }
    
    private func setupViewOnAppear() {
        buttonRefreshTrigger.toggle()
        tabBarController.hideTabBar()
        
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let window = windowScene.windows.first,
           let navigationController = window.rootViewController?.children.first as? UINavigationController {
            navigationController.interactivePopGestureRecognizer?.isEnabled = true
            navigationController.interactivePopGestureRecognizer?.delegate = nil
        }
    }
    
    private func setupInitialData() async {
        guard !hasFetched else { return }
        
        let savedCustomID = UserDefaults.standard.integer(forKey: "custom_anilist_id_\(href)")
        if savedCustomID != 0 { customAniListID = savedCustomID }
        
        if let savedPoster = UserDefaults.standard.string(forKey: "tmdbPosterURL_\(href)") {
            imageUrl = savedPoster
        }
        
        DropManager.shared.showDrop(
            title: "Fetching Data",
            subtitle: "Please wait while fetching.",
            duration: 0.5,
            icon: UIImage(systemName: "arrow.triangle.2.circlepath")
        )
        
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
    
    private func cancelCurrentFetch() {
        activeFetchID = nil
        isFetchingEpisode = false
        showStreamLoadingView = false
        showLoadingAlert = false
    }
    
    private func copyTitleToClipboard() {
        UIPasteboard.general.string = title
        DropManager.shared.showDrop(
            title: "Copied to Clipboard",
            subtitle: "",
            duration: 1.0,
            icon: UIImage(systemName: "doc.on.clipboard.fill")
        )
    }
    
    private func toggleBookmark() {
        libraryManager.toggleBookmark(
            title: title,
            imageUrl: imageUrl,
            href: href,
            moduleId: module.id.uuidString,
            moduleName: module.metadata.sourceName
        )
    }
    
    private func toggleSingleEpisodeWatchStatus() {
        if let ep = episodeLinks.first {
            let lastPlayedTime = UserDefaults.standard.double(forKey: "lastPlayedTime_\(ep.href)")
            let totalTime = UserDefaults.standard.double(forKey: "totalTime_\(ep.href)")
            let progress = totalTime > 0 ? lastPlayedTime / totalTime : 0
            
            if progress <= 0.9 {
                UserDefaults.standard.set(99999999.0, forKey: "lastPlayedTime_\(ep.href)")
                UserDefaults.standard.set(99999999.0, forKey: "totalTime_\(ep.href)")
                DropManager.shared.showDrop(
                    title: "Marked as Watched",
                    subtitle: "",
                    duration: 1.0,
                    icon: UIImage(systemName: "checkmark.circle.fill")
                )
            } else {
                UserDefaults.standard.set(0.0, forKey: "lastPlayedTime_\(ep.href)")
                UserDefaults.standard.set(0.0, forKey: "totalTime_\(ep.href)")
                DropManager.shared.showDrop(
                    title: "Progress Reset",
                    subtitle: "",
                    duration: 1.0,
                    icon: UIImage(systemName: "arrow.counterclockwise")
                )
            }
        }
    }
    
    private func downloadSingleEpisode() {
        if let ep = episodeLinks.first {
            let downloadStatus = jsController.isEpisodeDownloadedOrInProgress(
                showTitle: title,
                episodeNumber: ep.number,
                season: 1
            )
            
            if downloadStatus == .notDownloaded {
                downloadSingleEpisodeDirectly(episode: ep)
                DropManager.shared.showDrop(
                    title: "Starting Download",
                    subtitle: "",
                    duration: 1.0,
                    icon: UIImage(systemName: "arrow.down.circle")
                )
            } else {
                DropManager.shared.showDrop(
                    title: "Already Downloaded",
                    subtitle: "",
                    duration: 1.0,
                    icon: UIImage(systemName: "checkmark.circle")
                )
            }
        }
    }
    
    private func handleEpisodeSelection(episode: EpisodeLink, isSelected: Bool) {
        if isSelected {
            selectedEpisodes.insert(episode.number)
        } else {
            selectedEpisodes.remove(episode.number)
        }
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
    
    private func markAllPreviousEpisodes(episode: EpisodeLink, index: Int, inSeason: Bool) {
        if inSeason {
            markAllPreviousEpisodesAsWatched(ep: episode, inSeason: true)
        } else {
            markAllPreviousEpisodesInFlatList(ep: episode, index: index)
        }
    }
    
    private func handleAniListMatch(selectedID: Int) {
        self.customAniListID = selectedID
        self.itemID = selectedID
        UserDefaults.standard.set(selectedID, forKey: "custom_anilist_id_\(href)")
        self.fetchDetails()
        isMatchingPresented = false
    }
    
    private func resetAniListID() {
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
    }
    
    private func openAniListPage(id: Int) {
        if let url = URL(string: "https://anilist.co/anime/\(id)") {
            openSafariViewController(with: url.absoluteString)
        }
    }
    
    private func restoreOriginalPoster() {
        if let originalPoster = UserDefaults.standard.string(forKey: "originalPoster_\(href)") {
            imageUrl = originalPoster
            UserDefaults.standard.removeObject(forKey: "tmdbPosterURL_\(href)")
            UserDefaults.standard.removeObject(forKey: "originalPoster_\(href)")
        }
    }
    
    private func logDebugInfo() {
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
    }
    
    private func getBannerImageBasedOnAppearance() -> String {
        let isLightMode = selectedAppearance == .light || (selectedAppearance == .system && colorScheme == .light)
        return isLightMode
        ? "https://raw.githubusercontent.com/cranci1/Sora/refs/heads/dev/assets/banner1.png"
        : "https://raw.githubusercontent.com/cranci1/Sora/refs/heads/dev/assets/banner2.png"
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
    
    private func cleanTitle(_ title: String?) -> String {
        guard let title = title else { return "Unknown" }
        
        let cleaned = title.replacingOccurrences(
            of: "\\s*\\([^\\)]*\\)",
            with: "",
            options: .regularExpression
        ).trimmingCharacters(in: .whitespaces)
        
        return cleaned.isEmpty ? "Unknown" : cleaned
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
    
    private func selectNextEpisode() {
        guard let currentIndex = episodeLinks.firstIndex(where: { $0.number == selectedEpisodeNumber }),
              currentIndex + 1 < episodeLinks.count else {
            Logger.shared.log("No more episodes to play", type: "Info")
            return
        }
        
        let nextEpisode = episodeLinks[currentIndex + 1]
        selectedEpisodeNumber = nextEpisode.number
        fetchStream(href: nextEpisode.href)
        DropManager.shared.showDrop(
            title: "Fetching Next Episode",
            subtitle: "",
            duration: 0.5,
            icon: UIImage(systemName: "arrow.triangle.2.circlepath")
        )
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
                        let currentPosterKey = "originalPoster_\(self.href)"
                        let currentPoster = self.imageUrl
                        UserDefaults.standard.set(currentPoster, forKey: currentPosterKey)
                        self.imageUrl = imageUrl
                        UserDefaults.standard.set(imageUrl, forKey: "tmdbPosterURL_\(self.href)")
                    }
                }
            } catch {
                Logger.shared.log("Failed to parse TMDB poster: \(error.localizedDescription)", type: "Error")
            }
        }.resume()
    }
    
    
    func fetchStream(href: String) {
        let fetchID = UUID()
        activeFetchID = fetchID
        currentStreamTitle = "Episode \(selectedEpisodeNumber)"
        showLoadingAlert = true
        isFetchingEpisode = true
        
        let completion: ((streams: [String]?, subtitles: [String]?, sources: [[String: Any]]?)) -> Void = { result in
            guard self.activeFetchID == fetchID else { return }
            
            self.showLoadingAlert = false
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                guard self.activeFetchID == fetchID else { return }
                
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
        guard self.activeFetchID == fetchID else { return }
        
        self.isFetchingEpisode = false
        self.showLoadingAlert = false
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            guard self.activeFetchID == fetchID else { return }
            
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
                } else if let sources = sources as? [[String: Any]] {
                    if let currTitle = sources[index]["title"] as? String {
                        title = currTitle
                        streamUrl = (sources[index]["streamUrl"] as? String) ?? ""
                    } else {
                        title = "Stream \(streamIndex)"
                        streamUrl = (sources[index]["streamUrl"] as? String)!
                    }
                    headers = sources[index]["headers"] as? [String:String] ?? [:]
                    index += 1
                }
                
                alert.addAction(UIAlertAction(title: title, style: .default) { _ in
                    guard self.activeFetchID == fetchID else { return }
                    self.playStream(url: streamUrl, fullURL: href, subtitles: subtitles, headers: headers, fetchID: fetchID)
                })
                
                streamIndex += 1
            }
            
            alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
            
            self.presentAlert(alert)
        }
    }
    
    func playStream(url: String, fullURL: String, subtitles: String? = nil, headers: [String:String]? = nil, fetchID: UUID) {
        guard self.activeFetchID == fetchID else { return }
        
        self.isFetchingEpisode = false
        self.showLoadingAlert = false
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            guard self.activeFetchID == fetchID else { return }
            
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
                self.presentDefaultPlayer(url: url, fullURL: fullURL, subtitles: subtitles, headers: headers)
                return
            default:
                break
            }
            
            if let scheme = scheme, let url = URL(string: scheme), UIApplication.shared.canOpenURL(url) {
                UIApplication.shared.open(url, options: [:], completionHandler: nil)
                Logger.shared.log("Opening external app with scheme: \(url)", type: "General")
            } else {
                self.presentCustomPlayer(url: url, fullURL: fullURL, subtitles: subtitles, headers: headers, fetchID: fetchID)
            }
        }
    }
    
    private func presentDefaultPlayer(url: String, fullURL: String, subtitles: String?, headers: [String:String]?) {
        let videoPlayerViewController = VideoPlayerViewController(module: module)
        videoPlayerViewController.headers = headers
        videoPlayerViewController.streamUrl = url
        videoPlayerViewController.fullUrl = fullURL
        videoPlayerViewController.episodeNumber = selectedEpisodeNumber
        videoPlayerViewController.seasonNumber = selectedSeason + 1
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
    }
    
    private func presentCustomPlayer(url: String, fullURL: String, subtitles: String?, headers: [String:String]?, fetchID: UUID) {
        guard let url = URL(string: url) else {
            Logger.shared.log("Invalid stream URL: \(url)", type: "Error")
            DropManager.shared.showDrop(title: "Error", subtitle: "Invalid stream URL", duration: 2.0, icon: UIImage(systemName: "xmark.circle"))
            return
        }
        
        guard self.activeFetchID == fetchID else { return }
        
        let customMediaPlayer = CustomMediaPlayerViewController(
            module: module,
            urlString: url.absoluteString,
            fullUrl: fullURL,
            title: title,
            episodeNumber: selectedEpisodeNumber,
            onWatchNext: { selectNextEpisode() },
            subtitlesURL: subtitles,
            aniListID: itemID ?? 0,
            totalEpisodes: episodeLinks.count,
            episodeImageUrl: selectedEpisodeImage,
            headers: headers ?? nil
        )
        customMediaPlayer.seasonNumber = selectedSeason + 1
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
    
    
    private func downloadSingleEpisodeDirectly(episode: EpisodeLink) {
        if isSingleEpisodeDownloading { return }
        
        isSingleEpisodeDownloading = true
        DropManager.shared.downloadStarted(episodeNumber: episode.number)
        
        Task {
            do {
                let jsContent = try moduleManager.getModuleContent(module)
                jsController.loadScript(jsContent)
                tryNextSingleDownloadMethod(episode: episode, methodIndex: 0, softsub: module.metadata.softsub == true)
            } catch {
                DropManager.shared.error("Failed to start download: \(error.localizedDescription)")
                isSingleEpisodeDownloading = false
            }
        }
    }
    
    private func tryNextSingleDownloadMethod(episode: EpisodeLink, methodIndex: Int, softsub: Bool) {
        if !isSingleEpisodeDownloading { return }
        
        switch methodIndex {
        case 0:
            if module.metadata.asyncJS == true {
                jsController.fetchStreamUrlJS(episodeUrl: episode.href, softsub: softsub, module: module) { result in
                    self.handleSingleDownloadResult(result, episode: episode, methodIndex: methodIndex, softsub: softsub)
                }
            } else {
                tryNextSingleDownloadMethod(episode: episode, methodIndex: methodIndex + 1, softsub: softsub)
            }
        case 1:
            if module.metadata.streamAsyncJS == true {
                jsController.fetchStreamUrlJSSecond(episodeUrl: episode.href, softsub: softsub, module: module) { result in
                    self.handleSingleDownloadResult(result, episode: episode, methodIndex: methodIndex, softsub: softsub)
                }
            } else {
                tryNextSingleDownloadMethod(episode: episode, methodIndex: methodIndex + 1, softsub: softsub)
            }
        case 2:
            jsController.fetchStreamUrl(episodeUrl: episode.href, softsub: softsub, module: module) { result in
                self.handleSingleDownloadResult(result, episode: episode, methodIndex: methodIndex, softsub: softsub)
            }
        default:
            DropManager.shared.error("Failed to find a valid stream for download after trying all methods")
            isSingleEpisodeDownloading = false
        }
    }
    
    private func handleSingleDownloadResult(_ result: (streams: [String]?, subtitles: [String]?, sources: [[String:Any]]?), episode: EpisodeLink, methodIndex: Int, softsub: Bool) {
        if !isSingleEpisodeDownloading { return }
        
        if let sources = result.sources, !sources.isEmpty {
            if sources.count > 1 {
                showSingleDownloadStreamSelectionAlert(streams: sources, episode: episode, subtitleURL: result.subtitles?.first)
                return
            } else if let streamUrl = sources[0]["streamUrl"] as? String, let url = URL(string: streamUrl) {
                let subtitleURLString = sources[0]["subtitle"] as? String
                let subtitleURL = subtitleURLString.flatMap { URL(string: $0) }
                startSingleEpisodeDownloadWithProcessedStream(episode: episode, url: url, streamUrl: streamUrl, subtitleURL: subtitleURL)
                return
            }
        }
        
        if let streams = result.streams, !streams.isEmpty {
            if streams[0] == "[object Promise]" {
                tryNextSingleDownloadMethod(episode: episode, methodIndex: methodIndex + 1, softsub: softsub)
                return
            }
            
            if streams.count > 1 {
                showSingleDownloadStreamSelectionAlert(streams: streams, episode: episode, subtitleURL: result.subtitles?.first)
                return
            } else if let url = URL(string: streams[0]) {
                let subtitleURL = result.subtitles?.first.flatMap { URL(string: $0) }
                startSingleEpisodeDownloadWithProcessedStream(episode: episode, url: url, streamUrl: streams[0], subtitleURL: subtitleURL)
                return
            }
        }
        
        tryNextSingleDownloadMethod(episode: episode, methodIndex: methodIndex + 1, softsub: softsub)
    }
    
    private func showSingleDownloadStreamSelectionAlert(streams: [Any], episode: EpisodeLink, subtitleURL: String? = nil) {
        DispatchQueue.main.async {
            let alert = UIAlertController(title: "Select Download Server", message: "Choose a server to download Episode \(episode.number) from", preferredStyle: .actionSheet)
            
            var index = 0
            var streamIndex = 1
            
            while index < streams.count {
                var title: String = ""
                var streamUrl: String = ""
                
                if let streams = streams as? [String] {
                    if index + 1 < streams.count && !streams[index].lowercased().contains("http") {
                        title = streams[index]
                        streamUrl = streams[index + 1]
                        index += 2
                    } else {
                        title = "Server \(streamIndex)"
                        streamUrl = streams[index]
                        index += 1
                    }
                } else if let streams = streams as? [[String: Any]] {
                    title = (streams[index]["title"] as? String) ?? "Server \(streamIndex)"
                    streamUrl = (streams[index]["streamUrl"] as? String) ?? ""
                    index += 1
                }
                
                alert.addAction(UIAlertAction(title: title, style: .default) { _ in
                    guard let url = URL(string: streamUrl) else {
                        DropManager.shared.error("Invalid stream URL selected")
                        self.isSingleEpisodeDownloading = false
                        return
                    }
                    
                    var subtitleURL: URL? = nil
                    if let streams = streams as? [[String: Any]],
                       let subtitleURLString = streams[index-1]["subtitle"] as? String {
                        subtitleURL = URL(string: subtitleURLString)
                    }
                    
                    self.startSingleEpisodeDownloadWithProcessedStream(episode: episode, url: url, streamUrl: streamUrl, subtitleURL: subtitleURL)
                })
                
                streamIndex += 1
            }
            
            alert.addAction(UIAlertAction(title: "Cancel", style: .cancel) { _ in
                self.isSingleEpisodeDownloading = false
            })
            
            self.presentAlert(alert)
        }
    }
    
    private func startSingleEpisodeDownloadWithProcessedStream(episode: EpisodeLink, url: URL, streamUrl: String, subtitleURL: URL? = nil) {
        let headers = generateDownloadHeaders(for: url)
        
        fetchEpisodeMetadataForDownload(episode: episode) { metadata in
            let episodeTitle = metadata?.title["en"] ?? "Episode \(episode.number)"
            let episodeImageUrl = metadata?.imageUrl ?? ""
            
            let episodeThumbnailURL: URL?
            if !episodeImageUrl.isEmpty {
                episodeThumbnailURL = URL(string: episodeImageUrl)
            } else {
                episodeThumbnailURL = URL(string: self.getBannerImageBasedOnAppearance())
            }
            
            let showPosterImageURL = URL(string: self.imageUrl)
            
            self.jsController.downloadWithStreamTypeSupport(
                url: url,
                headers: headers,
                title: episodeTitle,
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
                        Logger.shared.log("Started download for Episode \(episode.number): \(episode.href)", type: "Download")
                        AnalyticsManager.shared.sendEvent(
                            event: "download",
                            additionalData: ["episode": episode.number, "url": streamUrl]
                        )
                    } else {
                        DropManager.shared.error(message)
                    }
                    self.isSingleEpisodeDownloading = false
                }
            )
        }
    }
    
    private func generateDownloadHeaders(for url: URL) -> [String: String] {
        var headers: [String: String] = [:]
        
        if !module.metadata.baseUrl.isEmpty && !module.metadata.baseUrl.contains("undefined") {
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
                headers = ["User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/134.0.0.0 Safari/537.36"]
                Logger.shared.log("Warning: Missing URL scheme/host for episode, using minimal headers", type: "Warning")
            }
        }
        
        return headers
    }
    
    private func fetchEpisodeMetadataForDownload(episode: EpisodeLink, completion: @escaping (EpisodeMetadataInfo?) -> Void) {
        guard let anilistId = itemID else {
            Logger.shared.log("No AniList ID available for episode metadata", type: "Warning")
            completion(nil as EpisodeMetadataInfo?)
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
        
        URLSession.custom.dataTask(with: url) { data, response, error in
            if let error = error {
                Logger.shared.log("Failed to fetch episode metadata: \(error)", type: "Error")
                completion(nil as EpisodeMetadataInfo?)
                return
            }
            
            guard let data = data else {
                Logger.shared.log("No data received for episode metadata", type: "Error")
                completion(nil as EpisodeMetadataInfo?)
                return
            }
            
            do {
                let jsonObject = try JSONSerialization.jsonObject(with: data, options: [])
                guard let json = jsonObject as? [String: Any],
                      let episodes = json["episodes"] as? [String: Any],
                      let episodeDetails = episodes["\(episodeNumber)"] as? [String: Any] else {
                    Logger.shared.log("Episode \(episodeNumber) not found in metadata response", type: "Warning")
                    completion(nil as EpisodeMetadataInfo?)
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
                
                completion(metadataInfo)
                
            } catch {
                Logger.shared.log("JSON parsing error for episode metadata: \(error.localizedDescription)", type: "Error")
                completion(nil as EpisodeMetadataInfo?)
            }
        }.resume()
    }
    
    
    private func presentAlert(_ alert: UIAlertController) {
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
