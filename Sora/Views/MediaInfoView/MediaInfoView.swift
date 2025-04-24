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
    
    @StateObject private var jsController = JSController()
    @EnvironmentObject var moduleManager: ModuleManager
    @EnvironmentObject private var libraryManager: LibraryManager
    
    @State private var selectedRange: Range<Int> = 0..<100
    @State private var showSettingsMenu = false
    @State private var customAniListID: Int?
    @State private var showStreamLoadingView: Bool = false
    @State private var currentStreamTitle: String = ""
    
    @State private var activeFetchID: UUID? = nil
    @Environment(\.dismiss) private var dismiss
    
    private var isGroupedBySeasons: Bool {
        return groupedEpisodes().count > 1
    }
    
    var body: some View {
        ZStack {
            Group {
                if isLoading {
                    ProgressView()
                        .padding()
                } else {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 16) {
                            HStack(alignment: .top, spacing: 10) {
                                KFImage(URL(string: imageUrl))
                                    .placeholder {
                                        RoundedRectangle(cornerRadius: 10)
                                            .fill(Color.gray.opacity(0.3))
                                            .frame(width: 150, height: 225)
                                            .shimmering()
                                    }
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                                    .frame(width: 150, height: 225)
                                    .clipped()
                                    .cornerRadius(10)
                                
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(title)
                                        .font(.system(size: 17))
                                        .fontWeight(.bold)
                                        .onLongPressGesture {
                                            UIPasteboard.general.string = title
                                            DropManager.shared.showDrop(title: "Copied to Clipboard", subtitle: "", duration: 1.0, icon: UIImage(systemName: "doc.on.clipboard.fill"))
                                        }
                                    
                                    if !aliases.isEmpty && aliases != title && aliases != "N/A" && aliases != "No Data" {
                                        Text(aliases)
                                            .font(.system(size: 13))
                                            .foregroundColor(.secondary)
                                    }
                                    
                                    Spacer()
                                    
                                    if !airdate.isEmpty && airdate != "N/A" && airdate != "No Data" {
                                        HStack(alignment: .center, spacing: 12) {
                                            HStack(spacing: 4) {
                                                Image(systemName: "calendar")
                                                    .resizable()
                                                    .frame(width: 15, height: 15)
                                                    .foregroundColor(.secondary)
                                                
                                                Text(airdate)
                                                    .font(.system(size: 12))
                                                    .foregroundColor(.secondary)
                                            }
                                            .padding(4)
                                        }
                                    }
                                    
                                    HStack(alignment: .center, spacing: 12) {
                                        Button(action: {
                                            openSafariViewController(with: href)
                                        }) {
                                            HStack(spacing: 4) {
                                                Text(module.metadata.sourceName)
                                                    .font(.system(size: 13))
                                                    .foregroundColor(.primary)
                                                
                                                Image(systemName: "safari")
                                                    .resizable()
                                                    .frame(width: 20, height: 20)
                                                    .foregroundColor(.primary)
                                            }
                                            .padding(4)
                                            .background(Capsule().fill(Color.accentColor.opacity(0.4)))
                                        }
                                        
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
                                            Image(systemName: "ellipsis.circle")
                                                .resizable()
                                                .frame(width: 20, height: 20)
                                                .foregroundColor(.primary)
                                        }
                                    }
                                }
                            }
                            
                            if !synopsis.isEmpty {
                                VStack(alignment: .leading, spacing: 2) {
                                    HStack(alignment: .center) {
                                        Text("Synopsis")
                                            .font(.system(size: 18))
                                            .fontWeight(.bold)
                                        
                                        Spacer()
                                        
                                        Button(action: {
                                            showFullSynopsis.toggle()
                                        }) {
                                            Text(showFullSynopsis ? "Less" : "More")
                                                .font(.system(size: 14))
                                        }
                                    }
                                    
                                    Text(synopsis)
                                        .lineLimit(showFullSynopsis ? nil : 4)
                                        .font(.system(size: 14))
                                }
                            }
                            
                            HStack {
                                Button(action: {
                                    playFirstUnwatchedEpisode()
                                }) {
                                    HStack {
                                        Image(systemName: "play.fill")
                                            .foregroundColor(.primary)
                                        Text(startWatchingText)
                                            .font(.headline)
                                            .foregroundColor(.primary)
                                    }
                                    .padding()
                                    .frame(maxWidth: .infinity)
                                    .background(Color.accentColor)
                                    .cornerRadius(10)
                                }
                                .disabled(isFetchingEpisode)
                                .id(buttonRefreshTrigger)
                                
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
                                        .frame(width: 20, height: 27)
                                        .foregroundColor(Color.accentColor)
                                }
                            }
                            
                            if !episodeLinks.isEmpty {
                                VStack(alignment: .leading, spacing: 10) {
                                    HStack {
                                        Text("Episodes")
                                            .font(.system(size: 18))
                                            .fontWeight(.bold)
                                        
                                        Spacer()
                                        
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
                                    if isGroupedBySeasons {
                                        let seasons = groupedEpisodes()
                                        if !seasons.isEmpty, selectedSeason < seasons.count {
                                            ForEach(seasons[selectedSeason]) { ep in
                                                let lastPlayedTime = UserDefaults.standard.double(forKey: "lastPlayedTime_\(ep.href)")
                                                let totalTime = UserDefaults.standard.double(forKey: "totalTime_\(ep.href)")
                                                let progress = totalTime > 0 ? lastPlayedTime / totalTime : 0
                                                
                                                EpisodeCell(
                                                    episodeIndex: selectedSeason,
                                                    episode: ep.href,
                                                    episodeID: ep.number - 1,
                                                    progress: progress,
                                                    itemID: itemID ?? 0,
                                                    onTap: { imageUrl in
                                                        if !isFetchingEpisode {
                                                            selectedEpisodeNumber = ep.number
                                                            selectedEpisodeImage = imageUrl
                                                            fetchStream(href: ep.href)
                                                            AnalyticsManager.shared.sendEvent(
                                                                event: "watch",
                                                                additionalData: ["title": title, "episode": ep.number]
                                                            )
                                                        }
                                                    },
                                                    onMarkAllPrevious: {
                                                        let userDefaults = UserDefaults.standard
                                                        var updates = [String: Double]()
                                                        
                                                        for ep2 in seasons[selectedSeason] where ep2.number < ep.number {
                                                            let href = ep2.href
                                                            updates["lastPlayedTime_\(href)"] = 99999999.0
                                                            updates["totalTime_\(href)"] = 99999999.0
                                                        }
                                                        
                                                        for (key, value) in updates {
                                                            userDefaults.set(value, forKey: key)
                                                        }
                                                        
                                                        userDefaults.synchronize()
                                                        
                                                        refreshTrigger.toggle()
                                                        Logger.shared.log("Marked episodes watched within season \(selectedSeason + 1) of \"\(title)\".", type: "General")
                                                    }
                                                )
                                                .id(refreshTrigger)
                                                .disabled(isFetchingEpisode)
                                            }
                                        } else {
                                            Text("No episodes available")
                                        }
                                    } else {
                                        ForEach(episodeLinks.indices.filter { selectedRange.contains($0) }, id: \.self) { i in
                                            let ep = episodeLinks[i]
                                            let lastPlayedTime = UserDefaults.standard.double(forKey: "lastPlayedTime_\(ep.href)")
                                            let totalTime = UserDefaults.standard.double(forKey: "totalTime_\(ep.href)")
                                            let progress = totalTime > 0 ? lastPlayedTime / totalTime : 0
                                            
                                            EpisodeCell(
                                                episodeIndex: i,
                                                episode: ep.href,
                                                episodeID: ep.number - 1,
                                                progress: progress,
                                                itemID: itemID ?? 0,
                                                onTap: { imageUrl in
                                                    if !isFetchingEpisode {
                                                        selectedEpisodeNumber = ep.number
                                                        selectedEpisodeImage = imageUrl
                                                        fetchStream(href: ep.href)
                                                        AnalyticsManager.shared.sendEvent(
                                                            event: "watch",
                                                            additionalData: ["title": title, "episode": ep.number]
                                                        )
                                                    }
                                                },
                                                onMarkAllPrevious: {
                                                    let userDefaults = UserDefaults.standard
                                                    var updates = [String: Double]()
                                                    
                                                    for idx in 0..<i {
                                                        if idx < episodeLinks.count {
                                                            let href = episodeLinks[idx].href
                                                            updates["lastPlayedTime_\(href)"] = 1000.0
                                                            updates["totalTime_\(href)"] = 1000.0
                                                        }
                                                    }
                                                    
                                                    for (key, value) in updates {
                                                        userDefaults.set(value, forKey: key)
                                                    }
                                                    
                                                    refreshTrigger.toggle()
                                                    Logger.shared.log("Marked \(ep.number - 1) episodes watched within series \"\(title)\".", type: "General")
                                                }
                                            )
                                            .id(refreshTrigger)
                                            .disabled(isFetchingEpisode)
                                        }
                                    }
                                }
                            } else {
                                VStack(alignment: .leading, spacing: 10) {
                                    Text("Episodes")
                                        .font(.system(size: 18))
                                        .fontWeight(.bold)
                                }
                                VStack(spacing: 8) {
                                    if isRefetching {
                                        ProgressView()
                                            .padding()
                                    } else {
                                        Image(systemName: "exclamationmark.triangle")
                                            .font(.largeTitle)
                                            .foregroundColor(.secondary)
                                        HStack(spacing: 2) {
                                            Text("No episodes Found:")
                                                .foregroundColor(.secondary)
                                            Button(action: {
                                                isRefetching = true
                                                fetchDetails()
                                            }) {
                                                Text("Retry")
                                                    .foregroundColor(.accentColor)
                                            }
                                        }
                                    }
                                }
                                .padding()
                                .frame(maxWidth: .infinity)
                            }
                        }
                        .padding()
                        .navigationBarTitleDisplayMode(.inline)
                        .navigationBarTitle("")
                        .navigationViewStyle(StackNavigationViewStyle())
                    }
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
                    
                    hasFetched = true
                    AnalyticsManager.shared.sendEvent(event: "search", additionalData: ["title": title])
                }
                selectedRange = 0..<episodeChunkSize
            }
            
            if showStreamLoadingView {
                VStack(spacing: 16) {
                    Text("Loading \(currentStreamTitle)…")
                        .font(.headline)
                        .foregroundColor(.primary)

                    Button("Cancel") {
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.6)) {
                            activeFetchID = nil
                            isFetchingEpisode = false
                            showStreamLoadingView = false
                        }
                    }
                    .font(.subheadline)
                    .padding(.vertical, 8)
                    .padding(.horizontal, 24)
                    .background(
                        // Hex #FF705E
                        Color(red: 1.0, green: 112/255.0, blue: 94/255.0)
                    )
                    .foregroundColor(.white)
                    .cornerRadius(8)
                }
                .padding(.top, 20)
                .padding(.bottom, 16)
                .padding(.horizontal, 40)
                .background(.ultraThinMaterial)
                .cornerRadius(16)
                .shadow(color: Color.black.opacity(0.3), radius: 12, x: 0, y: 8)
                .frame(maxWidth: 300)
                .transition(.scale.combined(with: .opacity))
                .animation(.spring(response: 0.4, dampingFraction: 0.6), value: showStreamLoadingView)
            }
        }
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button(action: {
                    activeFetchID = nil
                    isFetchingEpisode = false
                    showStreamLoadingView = false
                    dismiss()
                }) {
                    HStack {
                        Image(systemName: "chevron.left")
                        Text("Search")
                    }
                }
            }
        }
        .onDisappear {
            activeFetchID = nil
            isFetchingEpisode = false
            showStreamLoadingView = false
        }
    }
    
    private var startWatchingText: String {
        let (finished, unfinished) = finishedAndUnfinishedIndices()
        
        if let finishedIndex = finished, finishedIndex < episodeLinks.count - 1 {
            let nextEp = episodeLinks[finishedIndex + 1]
            return "Start Watching Episode \(nextEp.number)"
        } else if let unfinishedIndex = unfinished {
            return "Continue Watching Episode \(episodeLinks[unfinishedIndex].number)"
        }
        
        return "Start Watching"
    }
    
    private func playFirstUnwatchedEpisode() {
        let (finished, unfinished) = finishedAndUnfinishedIndices()
        
        if let finishedIndex = finished, finishedIndex < episodeLinks.count - 1 {
            let nextEp = episodeLinks[finishedIndex + 1]
            selectedEpisodeNumber = nextEp.number
            fetchStream(href: nextEp.href)
            return
        } else if let unfinishedIndex = unfinished {
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
        showStreamLoadingView = true
        isFetchingEpisode = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            Task {
                do {
                    let jsContent = try moduleManager.getModuleContent(module)
                    jsController.loadScript(jsContent)
                    
                    if module.metadata.softsub == true {
                        if module.metadata.asyncJS == true {
                            jsController.fetchStreamUrlJS(episodeUrl: href, softsub: true, module: module) { result in
                                guard self.activeFetchID == fetchID else { return }
                                
                                if let streams = result.streams, !streams.isEmpty {
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
                        } else if module.metadata.streamAsyncJS == true {
                            jsController.fetchStreamUrlJSSecond(episodeUrl: href, softsub: true, module: module) { result in
                                guard self.activeFetchID == fetchID else { return }
                                
                                if let streams = result.streams, !streams.isEmpty {
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
                        } else {
                            jsController.fetchStreamUrl(episodeUrl: href, softsub: true, module: module) { result in
                                guard self.activeFetchID == fetchID else { return }
                                
                                if let streams = result.streams, !streams.isEmpty {
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
                    } else {
                        if module.metadata.asyncJS == true {
                            jsController.fetchStreamUrlJS(episodeUrl: href, module: module) { result in
                                guard self.activeFetchID == fetchID else { return }
                                
                                if let streams = result.streams, !streams.isEmpty {
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
                        } else if module.metadata.streamAsyncJS == true {
                            jsController.fetchStreamUrlJSSecond(episodeUrl: href, module: module) { result in
                                guard self.activeFetchID == fetchID else { return }
                                
                                if let streams = result.streams, !streams.isEmpty {
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
                        } else {
                            jsController.fetchStreamUrl(episodeUrl: href, module: module) { result in
                                guard self.activeFetchID == fetchID else { return }
                                
                                if let streams = result.streams, !streams.isEmpty {
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
    
    func handleStreamFailure(error: Error? = nil) {
        self.isFetchingEpisode = false
        self.showStreamLoadingView = false
        if let error = error {
            Logger.shared.log("Error loading module: \(error)", type: "Error")
            AnalyticsManager.shared.sendEvent(event: "error", additionalData: ["error": error, "message": "Failed to fetch stream"])
        }
        DropManager.shared.showDrop(title: "Stream not Found", subtitle: "", duration: 0.5, icon: UIImage(systemName: "xmark"))
        
        UINotificationFeedbackGenerator().notificationOccurred(.error)
        self.isLoading = false
    }
    
    func showStreamSelectionAlert(streams: [String], fullURL: String, subtitles: String? = nil) {
        self.isFetchingEpisode = false
        self.showStreamLoadingView = false
        DispatchQueue.main.async {
            let alert = UIAlertController(title: "Select Server", message: "Choose a server to play from", preferredStyle: .actionSheet)
            
            var index = 0
            var streamIndex = 1
            
            while index < streams.count {
                let title: String
                let streamUrl: String
                
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
                
                alert.addAction(UIAlertAction(title: title, style: .default) { _ in
                    self.playStream(url: streamUrl, fullURL: fullURL, subtitles: subtitles)
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
    
    func playStream(url: String, fullURL: String, subtitles: String? = nil) {
        self.isFetchingEpisode = false
        self.showStreamLoadingView = false
        DispatchQueue.main.async {
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
            case "Default":
                let videoPlayerViewController = VideoPlayerViewController(module: module)
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
                    episodeImageUrl: selectedEpisodeImage
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
            }
        })
        
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let window = windowScene.windows.first,
           let rootVC = window.rootViewController {
            findTopViewController.findViewController(rootVC).present(alert, animated: true)
        }
    }
}
