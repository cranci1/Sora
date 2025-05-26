//
//  MediaInfoView.swift
//  Sora
//
//  Created by Francesco on 05/01/25.
//

import SwiftUI
import Kingfisher
import SafariServices

struct MediaItem: Identifiable {
    let id = UUID()
    let description: String
    let aliases: String
    let airdate: String
}

struct MediaInfoView: View {
    let title: String
    let imageUrl: String
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
    
    @State private var isModuleSelectorPresented = false
    @State private var isError = false
    
    @StateObject private var jsController = JSController.shared
    @EnvironmentObject var moduleManager: ModuleManager
    @EnvironmentObject private var libraryManager: LibraryManager
    
    @State private var selectedRange: Range<Int> = 0..<100
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
        bodyContent
    }
    
    @ViewBuilder
    private var bodyContent: some View {
        ZStack {
            // Background gradient
            LinearGradient(
                gradient: Gradient(colors: [
                    Color.black.opacity(0.9),
                    Color.black.opacity(0.7),
                    Color.black
                ]),
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
            
            if isLoading {
                ProgressView()
                    .padding()
            } else {
                mainScrollView
            }
        }
        .onAppear {
            buttonRefreshTrigger.toggle()
            
            if !hasFetched {
                DropManager.shared.showDrop(title: "Fetching Data", subtitle: "Please wait while fetching.", duration: 0.5, icon: UIImage(systemName: "arrow.triangle.2.circlepath"))
                fetchDetails()
                
                if let savedID = UserDefaults.standard.object(forKey: "custom_anilist_id_\(href)") as? Int {
                    customAniListID = savedID
                    itemID = savedID
                    Logger.shared.log("Using custom AniList ID: \(savedID)", type: "Debug")
                } else {
                    fetchItemID(byTitle: cleanTitle(title)) { result in
                        switch result {
                        case .success(let id):
                            itemID = id
                        case .failure(let error):
                            Logger.shared.log("Failed to fetch AniList ID: \(error)")
                            AnalyticsManager.shared.sendEvent(event: "error", additionalData: ["error": error, "message": "Failed to fetch AniList ID"])
                        }
                    }
                }
                
                selectedRange = 0..<episodeChunkSize
                
                hasFetched = true
                AnalyticsManager.shared.sendEvent(event: "search", additionalData: ["title": title])
            }
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
    }
    
    @ViewBuilder
    private var mainScrollView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                // Compact header with poster overlay
                ZStack(alignment: .bottomLeading) {
                    // Poster background
                    KFImage(URL(string: imageUrl))
                        .placeholder {
                            Rectangle()
                                .fill(Color.gray.opacity(0.3))
                                .frame(height: 300)
                                .shimmering()
                        }
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(height: 300)
                        .clipped()
                        .overlay(
                            LinearGradient(
                                gradient: Gradient(colors: [
                                    Color.clear,
                                    Color.black.opacity(0.8)
                                ]),
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                    
                    // Content overlay
                    VStack(alignment: .leading, spacing: 8) {
                        // Title
                        Text(title)
                            .font(.system(size: 28, weight: .bold))
                            .foregroundColor(.white)
                            .lineLimit(2)
                            .onLongPressGesture {
                                UIPasteboard.general.string = title
                                DropManager.shared.showDrop(title: "Copied to Clipboard", subtitle: "", duration: 1.0, icon: UIImage(systemName: "doc.on.clipboard.fill"))
                            }
                        
                        // Synopsis
                        if !synopsis.isEmpty {
                            Text(synopsis)
                                .font(.system(size: 14))
                                .foregroundColor(.white.opacity(0.8))
                                .lineLimit(showFullSynopsis ? nil : 3)
                                .onTapGesture {
                                    showFullSynopsis.toggle()
                                }
                        }
                        
                        // Action buttons
                        HStack(spacing: 12) {
                            // Play button
                            Button(action: {
                                playFirstUnwatchedEpisode()
                            }) {
                                HStack(spacing: 8) {
                                    Image(systemName: "play.fill")
                                        .font(.system(size: 16, weight: .bold))
                                    Text(startWatchingText)
                                        .font(.system(size: 16, weight: .semibold))
                                }
                                .foregroundColor(.black)
                                .padding(.horizontal, 20)
                                .padding(.vertical, 12)
                                .background(Color.white)
                                .cornerRadius(25)
                            }
                            .disabled(isFetchingEpisode)
                            
                            // Bookmark button
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
                                    .font(.system(size: 20, weight: .bold))
                                    .foregroundColor(.white)
                                    .frame(width: 44, height: 44)
                                    .background(Color.black.opacity(0.6))
                                    .cornerRadius(22)
                            }
                        }
                        
                        // Source and metadata
                        HStack(spacing: 16) {
                            sourceButton
                            
                            if !airdate.isEmpty && airdate != "N/A" && airdate != "No Data" {
                                HStack(spacing: 4) {
                                    Image(systemName: "calendar")
                                        .font(.system(size: 12))
                                        .foregroundColor(.white.opacity(0.7))
                                    Text("Aired: \(airdate)")
                                        .font(.system(size: 12))
                                        .foregroundColor(.white.opacity(0.7))
                                }
                            }
                            
                            Spacer()
                            
                            menuButton
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 20)
                }
                
                // Episodes section
                VStack(alignment: .leading, spacing: 12) {
                    if !episodeLinks.isEmpty {
                        episodesSection
                    } else {
                        noEpisodesSection
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 20)
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarTitle("")
        .navigationViewStyle(StackNavigationViewStyle())
    }
    
    @ViewBuilder
    private var sourceButton: some View {
        Button(action: {
            openSafariViewController(with: href)
        }) {
            Text(module.metadata.sourceName)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.white)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Color.white.opacity(0.2))
                .cornerRadius(12)
        }
    }
    
    @ViewBuilder
    private var menuButton: some View {
        Menu {
            Button(action: {
                showCustomIDAlert()
            }) {
                Label("Set Custom AniList ID", systemImage: "number")
            }
            
            if let customID = customAniListID {
                Button(action: {
                    customAniListID = nil
                    itemID = nil
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
            
            Divider()
            
            Button(action: {
                Logger.shared.log("Debug Info:\nTitle: \(title)\nHref: \(href)\nModule: \(module.metadata.sourceName)\nAniList ID: \(itemID ?? -1)\nCustom ID: \(customAniListID ?? -1)", type: "Debug")
                DropManager.shared.showDrop(title: "Debug Info Logged", subtitle: "", duration: 1.0, icon: UIImage(systemName: "terminal"))
            }) {
                Label("Log Debug Info", systemImage: "terminal")
            }
        } label: {
            Image(systemName: "ellipsis")
                .font(.system(size: 16, weight: .bold))
                .foregroundColor(.white)
        }
    }
    
    @ViewBuilder
    private var episodesSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Episodes")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(.white)
                
                Spacer()
                episodeNavigationSection
            }
            
            episodeListSection
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
                        .foregroundColor(.white.opacity(0.7))
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
                            .foregroundColor(.white.opacity(0.7))
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
    private var seasonsEpisodeList: some View {
        let seasons = groupedEpisodes()
        if !seasons.isEmpty, selectedSeason < seasons.count {
            LazyVStack(spacing: 8) {
                ForEach(seasons[selectedSeason]) { ep in
                    let lastPlayedTime = UserDefaults.standard.double(forKey: "lastPlayedTime_\(ep.href)")
                    let totalTime = UserDefaults.standard.double(forKey: "totalTime_\(ep.href)")
                    let progress = totalTime > 0 ? lastPlayedTime / totalTime : 0
                    
                    ModernEpisodeCell(
                        episode: ep,
                        progress: progress,
                        onTap: {
                            episodeTapAction(ep: ep, imageUrl: "")
                        }
                    )
                    .disabled(isFetchingEpisode)
                }
            }
        } else {
            Text("No episodes available")
                .foregroundColor(.white.opacity(0.7))
        }
    }
    
    @ViewBuilder
    private var flatEpisodeList: some View {
        LazyVStack(spacing: 8) {
            ForEach(episodeLinks.indices.filter { selectedRange.contains($0) }, id: \.self) { i in
                let ep = episodeLinks[i]
                let lastPlayedTime = UserDefaults.standard.double(forKey: "lastPlayedTime_\(ep.href)")
                let totalTime = UserDefaults.standard.double(forKey: "totalTime_\(ep.href)")
                let progress = totalTime > 0 ? lastPlayedTime / totalTime : 0
                
                ModernEpisodeCell(
                    episode: ep,
                    progress: progress,
                    onTap: {
                        episodeTapAction(ep: ep, imageUrl: "")
                    }
                )
                .disabled(isFetchingEpisode)
            }
        }
    }
    
    @ViewBuilder
    private var noEpisodesSection: some View {
        VStack(spacing: 16) {
            if isRefetching {
                ProgressView()
                    .padding()
            } else {
                VStack(spacing: 12) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.largeTitle)
                        .foregroundColor(.white.opacity(0.7))
                    
                    Text("No episodes found")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.white.opacity(0.7))
                    
                    Button(action: {
                        isRefetching = true
                        fetchDetails()
                    }) {
                        Text("Retry")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.white)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(Color.white.opacity(0.2))
                            .cornerRadius(16)
                    }
                }
            }
        }
        .padding()
        .frame(maxWidth: .infinity)
    }
    
    // Modern Episode Cell Component
    struct ModernEpisodeCell: View {
        let episode: EpisodeLink
        let progress: Double
        let onTap: () -> Void
        
        var body: some View {
            Button(action: onTap) {
                HStack(spacing: 12) {
                    // Episode thumbnail placeholder
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.gray.opacity(0.3))
                        .frame(width: 80, height: 45)
                        .overlay(
                            Image(systemName: "play.fill")
                                .foregroundColor(.white.opacity(0.7))
                                .font(.system(size: 16))
                        )
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Episode \(episode.number)")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.white)
                        
                        Text("Episode Title")
                            .font(.system(size: 14))
                            .foregroundColor(.white.opacity(0.7))
                    }
                    
                    Spacer()
                    
                    // Progress indicator
                    ZStack {
                        Circle()
                            .stroke(Color.white.opacity(0.3), lineWidth: 3)
                            .frame(width: 40, height: 40)
                        
                        Circle()
                            .trim(from: 0, to: progress)
                            .stroke(Color.white, lineWidth: 3)
                            .rotationEffect(.degrees(-90))
                            .frame(width: 40, height: 40)
                        
                        Text("\(Int(progress * 100))%")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.white)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(Color.white.opacity(0.1))
                .cornerRadius(12)
            }
            .buttonStyle(PlainButtonStyle())
        }
    }
    
    private var startWatchingText: String {
        let indices = finishedAndUnfinishedIndices()
        let finished = indices.finished
        let unfinished = indices.unfinished
        
        if let finishedIndex = finished, finishedIndex < episodeLinks.count - 1 {
            let nextEp = episodeLinks[finishedIndex + 1]
            return "Episode \(nextEp.number)"
        }
        
        if let unfinishedIndex = unfinished {
            let currentEp = episodeLinks[unfinishedIndex]
            return "Continue Episode \(currentEp.number)"
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
                
                if let streams = result.sources, !streams.isEmpty {
                    if streams.count > 1 {
                        self.showStreamSelectionAlert(streams: streams, fullURL: href, subtitles: result.subtitles?.first)
                    } else {
                        self.playStream(url: streams[0]["streamUrl"] as? String ?? "", fullURL: href, subtitles: result.subtitles?.first, headers: (streams[0]["headers"] as! [String : String]))
                    }
                }
                else if let streams = result.streams, !streams.isEmpty {
                    if streams.count > 1 {
                        self.showStreamSelectionAlert(streams: streams, fullURL: href, subtitles: result.subtitles?.first)
                    } else {
                        self.playStream(url: streams[0], fullURL: href, subtitles: result.subtitles?.first)
                    }
                } else {
                    self.handleStreamFailure(error: nil)
                }
                
                DispatchQueue.main.async {
                    self.isFetchingEpisode = false
                }
            }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
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
        if let streams = result.streams, !streams.isEmpty, let url = URL(string: streams[0]) {
            if streams[0] == "[object Promise]" {
                print("[Bulk Download] Method #\(methodIndex+1) returned a Promise object, trying next method")
                tryNextDownloadMethodForBulk(episode: episode, methodIndex: methodIndex + 1, softsub: softsub, continuation: continuation)
                return
            }
            
            print("[Bulk Download] Method #\(methodIndex+1) returned valid stream URL: \(streams[0])")
            
            let subtitleURL = result.subtitles?.first.flatMap { URL(string: $0) }
            if let subtitleURL = subtitleURL {
                print("[Bulk Download] Found subtitle URL: \(subtitleURL.absoluteString)")
            }
            
            startEpisodeDownloadWithProcessedStream(episode: episode, url: url, streamUrl: streams[0], subtitleURL: subtitleURL)
            continuation.resume(returning: true)
            
        } else if let sources = result.sources, !sources.isEmpty,
                    let streamUrl = sources[0]["streamUrl"] as? String,
                    let url = URL(string: streamUrl) {
            
            print("[Bulk Download] Method #\(methodIndex+1) returned valid stream URL with headers: \(streamUrl)")
            
            let subtitleURLString = sources[0]["subtitle"] as? String
            let subtitleURL = subtitleURLString.flatMap { URL(string: $0) }
            if let subtitleURL = subtitleURL {
                print("[Bulk Download] Found subtitle URL: \(subtitleURL.absoluteString)")
            }
            
            startEpisodeDownloadWithProcessedStream(episode: episode, url: url, streamUrl: streamUrl, subtitleURL: subtitleURL)
            continuation.resume(returning: true)
            
        } else {
            print("[Bulk Download] Method #\(methodIndex+1) did not return valid streams, trying next method")
            tryNextDownloadMethodForBulk(episode: episode, methodIndex: methodIndex + 1, softsub: softsub, continuation: continuation)
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
        
        if MetadataCacheManager.shared.isCachingEnabled {
            let cacheKey = "anilist_\(anilistId)_episode_\(episode.number)"
            
            if let cachedData = MetadataCacheManager.shared.getMetadata(forKey: cacheKey),
               let metadata = EpisodeMetadata.fromData(cachedData) {
                
                print("[Bulk Download] Using cached metadata for episode \(episode.number)")
                let metadataInfo = EpisodeMetadataInfo(
                    title: metadata.title,
                    imageUrl: metadata.imageUrl,
                    anilistId: metadata.anilistId,
                    episodeNumber: metadata.episodeNumber
                )
                completion(metadataInfo)
                return
            }
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
                if MetadataCacheManager.shared.isCachingEnabled {
                    let metadata = EpisodeMetadata(
                        title: title,
                        imageUrl: image,
                        anilistId: anilistId,
                        episodeNumber: episodeNumber
                    )
                    
                    let cacheKey = "anilist_\(anilistId)_episode_\(episodeNumber)"
                    if let metadataData = metadata.toData() {
                        MetadataCacheManager.shared.storeMetadata(
                            metadataData,
                            forKey: cacheKey
                        )
                    }
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
    
    // MARK: - Missing Helper Methods (added from backup)
    
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
            Media(search: \"\(title)\", type: ANIME) {
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

    func handleStreamFailure(error: Error? = nil) {
        self.isFetchingEpisode = false
        self.showLoadingAlert = false
        if let error = error {
            Logger.shared.log("Error loading module: \(error)", type: "Error")
            AnalyticsManager.shared.sendEvent(event: "error", additionalData: ["error": error, "message": "Failed to fetch stream"])
        }
        DropManager.shared.showDrop(title: "Stream not Found", subtitle: "", duration: 0.5, icon: UIImage(systemName: "xmark"))
        UINotificationFeedbackGenerator().notificationOccurred(.error)
        self.isLoading = false
    }

    func showStreamSelectionAlert(streams: [Any], fullURL: String, subtitles: String? = nil) {
        self.isFetchingEpisode = false
        self.showLoadingAlert = false
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            let alert = UIAlertController(title: "Select Server", message: "Choose a server to play from", preferredStyle: .actionSheet)
            var index = 0
            var streamIndex = 1
            while index < streams.count {
                var title: String = ""
                var streamUrl: String = ""
                var headers: [String:String]? = nil
                if let streams = streams as? [String] {
                    if index + 1 < streams.count {
                        if !streams[index].lowercased().contains("http") {
                            title = streams[index]
                            streamUrl = streams[index + 1]
                            index += 2
                        } else {
                            title = "Stream \(streamIndex)"
                            streamUrl = streams[index]
                            index += 1
                        }
                    } else {
                        title = "Stream \(streamIndex)"
                        streamUrl = streams[index]
                        index += 1
                    }
                } else if let streams = streams as? [[String: Any]] {
                    if let currTitle = streams[index]["title"] as? String {
                        title = currTitle
                        streamUrl = (streams[index]["streamUrl"] as? String) ?? ""
                    } else {
                        title = "Stream \(streamIndex)"
                        streamUrl = (streams[index]["streamUrl"] as? String) ?? ""
                    }
                    headers = streams[index]["headers"] as? [String:String] ?? [:]
                    index += 1
                }
                alert.addAction(UIAlertAction(title: title, style: .default) { _ in
                    self.playStream(url: streamUrl, fullURL: fullURL, subtitles: subtitles, headers: headers)
                })
                streamIndex += 1
            }
            alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
            if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
               let window = windowScene.windows.first,
               let rootVC = window.rootViewController {
                findTopViewController.findViewController(rootVC).present(alert, animated: true)
            }
            DispatchQueue.main.async {
                self.isFetchingEpisode = false
            }
        }
    }

    func playStream(url: String, fullURL: String, subtitles: String? = nil, headers: [String:String]? = nil) {
        self.isFetchingEpisode = false
        self.showLoadingAlert = false
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
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

    private func getBannerImageBasedOnAppearance() -> String {
        let isLightMode = selectedAppearance == .light || (selectedAppearance == .system && colorScheme == .light)
        return isLightMode
            ? "https://raw.githubusercontent.com/cranci1/Sora/refs/heads/dev/assets/banner1.png"
            : "https://raw.githubusercontent.com/cranci1/Sora/refs/heads/dev/assets/banner2.png"
    }
}
