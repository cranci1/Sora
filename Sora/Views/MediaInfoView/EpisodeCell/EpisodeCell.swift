//
//  EpisodeCell.swift
//  Sora
//
//  Created by Francesco on 18/12/24.
//

import NukeUI
import SwiftUI
import AVFoundation

struct EpisodeCell: View {
    let episodeIndex: Int
    let episode: String
    let episodeID: Int
    let progress: Double
    let itemID: Int
    let totalEpisodes: Int?
    let defaultBannerImage: String
    let module: ScrapingModule
    let parentTitle: String
    let showPosterURL: String?
    let tmdbID: Int?
    let seasonNumber: Int?
    
    let isMultiSelectMode: Bool
    let isSelected: Bool
    let onSelectionChanged: ((Bool) -> Void)?
    
    let onTap: (String) -> Void
    let onMarkAllPrevious: () -> Void
    
    @State private var episodeTitle = ""
    @State private var episodeImageUrl = ""
    @State private var isLoading = true
    @State private var currentProgress: Double = 0.0
    @State private var isDownloading = false
    @State private var downloadStatus: EpisodeDownloadStatus = .notDownloaded
    @State private var downloadAnimationScale: CGFloat = 1.0
    @State private var activeDownloadTask: AVAssetDownloadTask?
    
    @State private var swipeOffset: CGFloat = 0
    @State private var isShowingActions: Bool = false
    @State private var actionButtonWidth: CGFloat = 60
    @State private var dragState: DragState = .inactive
    
    @State private var retryAttempts: Int = 0
    private let maxRetryAttempts: Int = 3
    private let initialBackoffDelay: TimeInterval = 1.0
    
    @ObservedObject private var jsController = JSController.shared
    @EnvironmentObject var moduleManager: ModuleManager
    @Environment(\.colorScheme) private var colorScheme
    @AppStorage("selectedAppearance") private var selectedAppearance: Appearance = .system
    
    init(
        episodeIndex: Int,
        episode: String,
        episodeID: Int,
        progress: Double,
        itemID: Int,
        totalEpisodes: Int? = nil,
        defaultBannerImage: String = "",
        module: ScrapingModule,
        parentTitle: String,
        showPosterURL: String? = nil,
        isMultiSelectMode: Bool = false,
        isSelected: Bool = false,
        onSelectionChanged: ((Bool) -> Void)? = nil,
        onTap: @escaping (String) -> Void,
        onMarkAllPrevious: @escaping () -> Void,
        tmdbID: Int? = nil,
        seasonNumber: Int? = nil
    ) {
        self.episodeIndex = episodeIndex
        self.episode = episode
        self.episodeID = episodeID
        self.progress = progress
        self.itemID = itemID
        self.totalEpisodes = totalEpisodes
        self.module = module
        self.parentTitle = parentTitle
        self.showPosterURL = showPosterURL
        self.isMultiSelectMode = isMultiSelectMode
        self.isSelected = isSelected
        self.onSelectionChanged = onSelectionChanged
        self.onTap = onTap
        self.onMarkAllPrevious = onMarkAllPrevious
        self.tmdbID = tmdbID
        self.seasonNumber = seasonNumber
        
        
        let isLightMode = (UserDefaults.standard.string(forKey: "selectedAppearance") == "light") ||
        ((UserDefaults.standard.string(forKey: "selectedAppearance") == "system") &&
         UITraitCollection.current.userInterfaceStyle == .light)
        
        let defaultLightBanner = "https://raw.githubusercontent.com/cranci1/Sora/refs/heads/dev/assets/banner1.png"
        let defaultDarkBanner = "https://raw.githubusercontent.com/cranci1/Sora/refs/heads/dev/assets/banner2.png"
        
        self.defaultBannerImage = defaultBannerImage.isEmpty ?
        (isLightMode ? defaultLightBanner : defaultDarkBanner) : defaultBannerImage
    }
    
    var body: some View {
        ZStack {
            actionButtonsBackground
            
            episodeCellContent
        }
        .onAppear { setupOnAppear() }
        .onDisappear { activeDownloadTask = nil }
        .onChange(of: progress) { _ in updateProgress() }
        .onChange(of: itemID) { _ in handleItemIDChange() }
        .onChange(of: tmdbID) { _ in
            isLoading = true
            retryAttempts = 0
            fetchEpisodeDetails()
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("downloadProgressChanged"))) { _ in
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                updateDownloadStatus()
                updateProgress()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("downloadStatusChanged"))) { _ in
            updateDownloadStatus()
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("downloadCompleted"))) { _ in
            updateDownloadStatus()
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("episodeProgressChanged"))) { _ in
            updateProgress()
        }
    }
}

private extension EpisodeCell {
    
    var actionButtonsBackground: some View {
        HStack {
            Spacer()
            actionButtons
        }
        .zIndex(0)
    }
    
    var episodeCellContent: some View {
        HStack {
            episodeThumbnail
            episodeInfo
            Spacer()
            CircularProgressBar(progress: currentProgress)
                .frame(width: 40, height: 40)
                .padding(.trailing, 4)
        }
        .contentShape(Rectangle())
        .padding(.horizontal, 8)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity)
        .background(cellBackground)
        .clipShape(RoundedRectangle(cornerRadius: 15))
        .offset(x: swipeOffset + dragState.translation.width)
        .zIndex(1)
        .scaleEffect(dragState.isActive ? 0.98 : 1.0)
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: swipeOffset)
        .animation(.spring(response: 0.3, dampingFraction: 0.6), value: dragState.isActive)
        .contextMenu { contextMenuContent }
        .simultaneousGesture(
            DragGesture(coordinateSpace: .local)
                .onChanged { value in
                    handleDragChanged(value)
                }
                .onEnded { value in
                    handleDragEnded(value)
                }
        )
        .onTapGesture { handleTap() }
    }
    
    var cellBackground: some View {
        RoundedRectangle(cornerRadius: 15)
            .fill(Color(UIColor.systemBackground))
            .overlay(
                RoundedRectangle(cornerRadius: 15)
                    .fill(Color.gray.opacity(0.2))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 15)
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
    
    var episodeThumbnail: some View {
        ZStack {
            AsyncImageView(
                url: episodeImageUrl.isEmpty ? defaultBannerImage : episodeImageUrl,
                width: 100,
                height: 56
            )
            
            if isLoading {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle())
            }
        }
    }
    
    var episodeInfo: some View {
        VStack(alignment: .leading) {
            Text("Episode \(episodeID + 1)")
                .font(.system(size: 15))
            
            if !episodeTitle.isEmpty {
                Text(episodeTitle)
                    .font(.system(size: 13))
                    .foregroundColor(.secondary)
            }
        }
    }
    
    var contextMenuContent: some View {
        Group {
            if progress <= 0.9 {
                Button(action: markAsWatched) {
                    Label("Mark Episode as Watched", systemImage: "checkmark.circle")
                }
            }
            
            if progress != 0 {
                Button(action: resetProgress) {
                    Label("Reset Episode Progress", systemImage: "arrow.counterclockwise")
                }
            }
            
            if episodeIndex > 0 {
                Button(action: onMarkAllPrevious) {
                    Label("Mark Previous Episodes as Watched", systemImage: "checkmark.circle.fill")
                }
            }
            
            Button(action: downloadEpisode) {
                Label("Download This Episode", systemImage: "arrow.down.circle")
            }
        }
    }
    
    var actionButtons: some View {
        HStack(spacing: 8) {
            ActionButton(
                icon: "arrow.down.circle",
                label: "Download",
                color: .blue,
                width: actionButtonWidth
            ) {
                closeActionsAndPerform { downloadEpisode() }
            }
            
            if progress <= 0.9 {
                ActionButton(
                    icon: "checkmark.circle",
                    label: "Watched",
                    color: .green,
                    width: actionButtonWidth
                ) {
                    closeActionsAndPerform { markAsWatched() }
                }
            }
            
            if progress != 0 {
                ActionButton(
                    icon: "arrow.counterclockwise",
                    label: "Reset",
                    color: .orange,
                    width: actionButtonWidth
                ) {
                    closeActionsAndPerform { resetProgress() }
                }
            }
            
            if episodeIndex > 0 {
                ActionButton(
                    icon: "checkmark.circle.fill",
                    label: "All Prev",
                    color: .purple,
                    width: actionButtonWidth
                ) {
                    closeActionsAndPerform { onMarkAllPrevious() }
                }
            }
        }
        .padding(.horizontal, 8)
    }
}

private extension EpisodeCell {
    
    enum DragState {
        case inactive
        case pressing
        case dragging(translation: CGSize)
        
        var translation: CGSize {
            switch self {
            case .inactive, .pressing:
                return .zero
            case .dragging(let translation):
                return translation
            }
        }
        
        var isActive: Bool {
            switch self {
            case .inactive:
                return false
            case .pressing, .dragging:
                return true
            }
        }
        
        var isDragging: Bool {
            switch self {
            case .dragging:
                return true
            default:
                return false
            }
        }
    }
    
    func handleDragChanged(_ value: DragGesture.Value) {
        let translation = value.translation
        let velocity = value.velocity
        
        let isHorizontalGesture = abs(translation.width) > abs(translation.height)
        let hasSignificantHorizontalMovement = abs(translation.width) > 10
        
        if isHorizontalGesture && hasSignificantHorizontalMovement {
            dragState = .dragging(translation: .zero)
            
            let proposedOffset = swipeOffset + translation.width
            let maxSwipe = calculateMaxSwipeDistance()
            
            if translation.width < 0 {
                let newOffset = max(proposedOffset, -maxSwipe)
                if proposedOffset < -maxSwipe {
                    let resistance = abs(proposedOffset + maxSwipe) * 0.15
                    swipeOffset = -maxSwipe - resistance
                } else {
                    swipeOffset = newOffset
                }
            } else if isShowingActions {
                swipeOffset = max(proposedOffset, -maxSwipe)
            }
        } else if !hasSignificantHorizontalMovement {
            dragState = .inactive
        }
    }
    
    func handleDragEnded(_ value: DragGesture.Value) {
        let translation = value.translation
        let velocity = value.velocity
        
        dragState = .inactive
        
        let isHorizontalGesture = abs(translation.width) > abs(translation.height)
        let hasSignificantHorizontalMovement = abs(translation.width) > 10
        
        if isHorizontalGesture && hasSignificantHorizontalMovement {
            let maxSwipe = calculateMaxSwipeDistance()
            let threshold = maxSwipe * 0.3
            let velocityThreshold: CGFloat = 500
            
            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                if translation.width < -threshold || velocity.width < -velocityThreshold {
                    swipeOffset = -maxSwipe
                    isShowingActions = true
                } else if translation.width > threshold || velocity.width > velocityThreshold {
                    swipeOffset = 0
                    isShowingActions = false
                } else {
                    swipeOffset = isShowingActions ? -maxSwipe : 0
                }
            }
        } else {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                swipeOffset = isShowingActions ? -calculateMaxSwipeDistance() : 0
            }
        }
    }
    
    func handleTap() {
        if isShowingActions {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                swipeOffset = 0
                isShowingActions = false
            }
        } else if isMultiSelectMode {
            onSelectionChanged?(!isSelected)
        } else {
            let imageUrl = episodeImageUrl.isEmpty ? defaultBannerImage : episodeImageUrl
            onTap(imageUrl)
        }
    }
    
    func calculateMaxSwipeDistance() -> CGFloat {
        var buttonCount = 1
        
        if progress <= 0.9 { buttonCount += 1 }
        if progress != 0 { buttonCount += 1 }
        if episodeIndex > 0 { buttonCount += 1 }
        
        var swipeDistance = CGFloat(buttonCount) * actionButtonWidth + 16
        
        if buttonCount == 3 { swipeDistance += 12 }
        else if buttonCount == 4 { swipeDistance += 24 }
        
        return swipeDistance
    }
}

private extension EpisodeCell {
    
    func closeActionsAndPerform(action: @escaping () -> Void) {
        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
            isShowingActions = false
            swipeOffset = 0
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            action()
        }
    }
    
    func markAsWatched() {
        let defaults = UserDefaults.standard
        let totalTime = 1000.0
        defaults.set(totalTime, forKey: "lastPlayedTime_\(episode)")
        defaults.set(totalTime, forKey: "totalTime_\(episode)")
        updateProgress()
        
        if itemID > 0 {
            let epNum = episodeID + 1
            let newStatus = (epNum == totalEpisodes) ? "COMPLETED" : "CURRENT"
            AniListMutation().updateAnimeProgress(
                animeId: itemID,
                episodeNumber: epNum,
                status: newStatus
            ) { result in
                switch result {
                case .success:
                    Logger.shared.log("AniList sync: marked ep \(epNum) as \(newStatus)", type: "General")
                case .failure(let err):
                    Logger.shared.log("AniList sync failed: \(err.localizedDescription)", type: "Error")
                }
            }
        }
    }

    
    func resetProgress() {
        let userDefaults = UserDefaults.standard
        userDefaults.set(0.0, forKey: "lastPlayedTime_\(episode)")
        userDefaults.set(0.0, forKey: "totalTime_\(episode)")
        updateProgress()
    }
    
    func updateProgress() {
        let userDefaults = UserDefaults.standard
        let lastPlayedTime = userDefaults.double(forKey: "lastPlayedTime_\(episode)")
        let totalTime = userDefaults.double(forKey: "totalTime_\(episode)")
        currentProgress = totalTime > 0 ? min(lastPlayedTime / totalTime, 1.0) : 0
    }
    
    func updateDownloadStatus() {
        let newStatus = jsController.isEpisodeDownloadedOrInProgress(
            showTitle: parentTitle,
            episodeNumber: episodeID + 1
        )
        
        if downloadStatus != newStatus {
            downloadStatus = newStatus
        }
    }
}

private extension EpisodeCell {
    func setupOnAppear() {
        updateProgress()
        updateDownloadStatus()
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            if UserDefaults.standard.string(forKey: "metadataProviders") ?? "TMDB" == "TMDB" {
                fetchTMDBEpisodeImage()
            } else {
                fetchAnimeEpisodeDetails()
            }
        }
    }
    
    func handleItemIDChange() {
        isLoading = true
        retryAttempts = 0
        fetchEpisodeDetails()
    }
    
    func fetchEpisodeDetails() {
        fetchAnimeEpisodeDetails()
    }
}

private extension EpisodeCell {
    
    func downloadEpisode() {
        updateDownloadStatus()
        
        guard case .notDownloaded = downloadStatus, !isDownloading else {
            handleAlreadyDownloadedOrInProgress()
            return
        }
        
        isDownloading = true
        let downloadID = UUID()
        
        DropManager.shared.downloadStarted(episodeNumber: episodeID + 1)
        
        Task {
            do {
                let jsContent = try moduleManager.getModuleContent(module)
                jsController.loadScript(jsContent)
                tryNextDownloadMethod(methodIndex: 0, downloadID: downloadID, softsub: module.metadata.softsub == true)
            } catch {
                DropManager.shared.error("Failed to start download: \(error.localizedDescription)")
                isDownloading = false
            }
        }
    }
    
    func handleAlreadyDownloadedOrInProgress() {
        switch downloadStatus {
        case .downloaded:
            DropManager.shared.info("Episode \(episodeID + 1) is already downloaded")
        case .downloading:
            DropManager.shared.info("Episode \(episodeID + 1) is already being downloaded")
        case .notDownloaded:
            break
        }
    }
    
    func tryNextDownloadMethod(methodIndex: Int, downloadID: UUID, softsub: Bool) {
        guard isDownloading else { return }
        
        switch methodIndex {
        case 0:
            if module.metadata.asyncJS == true {
                jsController.fetchStreamUrlJS(episodeUrl: episode, softsub: softsub, module: module) { result in
                    self.handleDownloadResult(result, downloadID: downloadID, methodIndex: methodIndex, softsub: softsub)
                }
            } else {
                tryNextDownloadMethod(methodIndex: methodIndex + 1, downloadID: downloadID, softsub: softsub)
            }
            
        case 1:
            if module.metadata.streamAsyncJS == true {
                jsController.fetchStreamUrlJSSecond(episodeUrl: episode, softsub: softsub, module: module) { result in
                    self.handleDownloadResult(result, downloadID: downloadID, methodIndex: methodIndex, softsub: softsub)
                }
            } else {
                tryNextDownloadMethod(methodIndex: methodIndex + 1, downloadID: downloadID, softsub: softsub)
            }
            
        case 2:
            jsController.fetchStreamUrl(episodeUrl: episode, softsub: softsub, module: module) { result in
                self.handleDownloadResult(result, downloadID: downloadID, methodIndex: methodIndex, softsub: softsub)
            }
            
        default:
            DropManager.shared.error("Failed to find a valid stream for download after trying all methods")
            isDownloading = false
        }
    }
    
    func handleDownloadResult(
        _ result: (streams: [String]?, subtitles: [String]?, sources: [[String: Any]]?),
        downloadID: UUID,
        methodIndex: Int,
        softsub: Bool
    ) {
        guard isDownloading else { return }
        
        if let sources = result.sources, !sources.isEmpty {
            if sources.count > 1 {
                showDownloadStreamSelectionAlert(streams: sources, downloadID: downloadID, subtitleURL: result.subtitles?.first)
                return
            } else if let streamUrl = sources[0]["streamUrl"] as? String, let url = URL(string: streamUrl) {
                let subtitleURLString = sources[0]["subtitle"] as? String
                let subtitleURL = subtitleURLString.flatMap { URL(string: $0) }
                startActualDownload(url: url, streamUrl: streamUrl, downloadID: downloadID, subtitleURL: subtitleURL)
                return
            }
        }
        
        if let streams = result.streams, !streams.isEmpty {
            if streams[0] == "[object Promise]" {
                tryNextDownloadMethod(methodIndex: methodIndex + 1, downloadID: downloadID, softsub: softsub)
                return
            }
            
            if streams.count > 1 {
                showDownloadStreamSelectionAlert(streams: streams, downloadID: downloadID, subtitleURL: result.subtitles?.first)
                return
            } else if let url = URL(string: streams[0]) {
                let subtitleURL = result.subtitles?.first.flatMap { URL(string: $0) }
                startActualDownload(url: url, streamUrl: streams[0], downloadID: downloadID, subtitleURL: subtitleURL)
                return
            }
        }
        
        tryNextDownloadMethod(methodIndex: methodIndex + 1, downloadID: downloadID, softsub: softsub)
    }
    
    func startActualDownload(url: URL, streamUrl: String, downloadID: UUID, subtitleURL: URL? = nil) {
        let headers = createDownloadHeaders(for: url)
        let episodeThumbnailURL = URL(string: episodeImageUrl.isEmpty ? defaultBannerImage : episodeImageUrl)
        let showPosterImageURL = URL(string: showPosterURL ?? defaultBannerImage)
        
        let baseTitle = "Episode \(episodeID + 1)"
        let fullEpisodeTitle = episodeTitle.isEmpty ? baseTitle : "\(baseTitle): \(episodeTitle)"
        let animeTitle = parentTitle.isEmpty ? "Unknown Anime" : parentTitle
        
        jsController.downloadWithStreamTypeSupport(
            url: url,
            headers: headers,
            title: fullEpisodeTitle,
            imageURL: episodeThumbnailURL,
            module: module,
            isEpisode: true,
            showTitle: animeTitle,
            season: 1,
            episode: episodeID + 1,
            subtitleURL: subtitleURL,
            showPosterURL: showPosterImageURL
        ) { success, message in
            if success {
                Logger.shared.log("Started download for Episode \(self.episodeID + 1): \(self.episode)", type: "Download")
                AnalyticsManager.shared.sendEvent(
                    event: "download",
                    additionalData: ["episode": self.episodeID + 1, "url": streamUrl]
                )
            } else {
                DropManager.shared.error(message)
            }
            self.isDownloading = false
        }
    }
    
    func createDownloadHeaders(for url: URL) -> [String: String] {
        if !module.metadata.baseUrl.isEmpty && !module.metadata.baseUrl.contains("undefined") {
            return [
                "Origin": module.metadata.baseUrl,
                "Referer": module.metadata.baseUrl,
                "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/134.0.0.0 Safari/537.36",
                "Accept": "*/*",
                "Accept-Language": "en-US,en;q=0.9",
                "Sec-Fetch-Dest": "empty",
                "Sec-Fetch-Mode": "cors",
                "Sec-Fetch-Site": "same-origin"
            ]
        } else if let scheme = url.scheme, let host = url.host {
            let baseUrl = "\(scheme)://\(host)"
            return [
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
            DropManager.shared.error("Invalid stream URL - missing scheme or host")
            isDownloading = false
            return [:]
        }
    }
}

private extension EpisodeCell {
    
    func showDownloadStreamSelectionAlert(streams: [Any], downloadID: UUID, subtitleURL: String? = nil) {
        DispatchQueue.main.async {
            let alert = UIAlertController(
                title: "Select Download Server",
                message: "Choose a server to download from",
                preferredStyle: .actionSheet
            )
            
            addStreamActions(to: alert, streams: streams, downloadID: downloadID, subtitleURL: subtitleURL)
            
            alert.addAction(UIAlertAction(title: "Cancel", style: .cancel) { _ in
                self.isDownloading = false
            })
            
            presentAlert(alert)
        }
    }
    
    func addStreamActions(to alert: UIAlertController, streams: [Any], downloadID: UUID, subtitleURL: String?) {
        var index = 0
        var streamIndex = 1
        
        while index < streams.count {
            let (title, streamUrl, newIndex) = parseStreamInfo(streams: streams, index: index, streamIndex: streamIndex)
            index = newIndex
            
            alert.addAction(UIAlertAction(title: title, style: .default) { _ in
                guard let url = URL(string: streamUrl) else {
                    DropManager.shared.error("Invalid stream URL selected")
                    self.isDownloading = false
                    return
                }
                
                let subtitleURLObj = subtitleURL.flatMap { URL(string: $0) }
                self.startActualDownload(url: url, streamUrl: streamUrl, downloadID: downloadID, subtitleURL: subtitleURLObj)
            })
            
            streamIndex += 1
        }
    }
    
    func parseStreamInfo(streams: [Any], index: Int, streamIndex: Int) -> (title: String, streamUrl: String, newIndex: Int) {
        if let streams = streams as? [String] {
            if index + 1 < streams.count && !streams[index].lowercased().contains("http") {
                return (streams[index], streams[index + 1], index + 2)
            } else {
                return ("Server \(streamIndex)", streams[index], index + 1)
            }
        } else if let streams = streams as? [[String: Any]] {
            let title = streams[index]["title"] as? String ?? "Server \(streamIndex)"
            let streamUrl = streams[index]["streamUrl"] as? String ?? ""
            return (title, streamUrl, index + 1)
        }
        
        return ("Server \(streamIndex)", "", index + 1)
    }
    
    func presentAlert(_ alert: UIAlertController) {
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let window = windowScene.windows.first,
              let rootVC = window.rootViewController else { return }
        
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
        
        findTopViewController(rootVC).present(alert, animated: true)
    }
    
    func findTopViewController(_ controller: UIViewController) -> UIViewController {
        if let navigationController = controller as? UINavigationController {
            return findTopViewController(navigationController.visibleViewController!)
        }
        if let tabController = controller as? UITabBarController {
            if let selected = tabController.selectedViewController {
                return findTopViewController(selected)
            }
        }
        if let presented = controller.presentedViewController {
            return findTopViewController(presented)
        }
        return controller
    }
}

private extension EpisodeCell {
    
    func fetchAnimeEpisodeDetails() {
        guard let url = URL(string: "https://api.ani.zip/mappings?anilist_id=\(itemID)") else {
            isLoading = false
            Logger.shared.log("Invalid URL for itemID: \(itemID)", type: "Error")
            return
        }
        
        if retryAttempts > 0 {
            Logger.shared.log("Retrying episode details fetch (attempt \(retryAttempts)/\(maxRetryAttempts))", type: "Debug")
        }
        
        URLSession.custom.dataTask(with: url) { data, response, error in
            if let error = error {
                Logger.shared.log("Failed to fetch anime episode details: \(error)", type: "Error")
                self.handleFetchFailure(error: error)
                return
            }
            
            guard let data = data else {
                self.handleFetchFailure(error: NetworkError.noData)
                return
            }
            
            self.processAnimeEpisodeData(data)
        }.resume()
    }
    
    func processAnimeEpisodeData(_ data: Data) {
        do {
            let jsonObject = try JSONSerialization.jsonObject(with: data, options: [])
            guard let json = jsonObject as? [String: Any],
                  let episodes = json["episodes"] as? [String: Any] else {
                handleFetchFailure(error: NetworkError.invalidJSON)
                return
            }
            
            let episodeKey = "\(episodeID + 1)"
            guard let episodeDetails = episodes[episodeKey] as? [String: Any] else {
                Logger.shared.log("Episode \(episodeKey) not found in response", type: "Error")
                DispatchQueue.main.async {
                    self.isLoading = false
                    self.retryAttempts = 0
                }
                return
            }
            
            updateEpisodeMetadata(from: episodeDetails)
            
        } catch {
            Logger.shared.log("JSON parsing error: \(error.localizedDescription)", type: "Error")
            DispatchQueue.main.async {
                self.isLoading = false
                self.retryAttempts = 0
            }
        }
    }
    
    func updateEpisodeMetadata(from episodeDetails: [String: Any]) {
        let title = episodeDetails["title"] as? [String: String] ?? [:]
        let image = episodeDetails["image"] as? String ?? ""
        
        DispatchQueue.main.async {
            self.isLoading = false
            self.retryAttempts = 0
            
            if UserDefaults.standard.object(forKey: "fetchEpisodeMetadata") == nil ||
                UserDefaults.standard.bool(forKey: "fetchEpisodeMetadata") {
                self.episodeTitle = title["en"] ?? title.values.first ?? ""
                
                if !image.isEmpty {
                    self.episodeImageUrl = image
                }
            }
        }
    }
    
    func fetchTMDBEpisodeImage() {
        guard let tmdbID = tmdbID, let season = seasonNumber else { return }
        
        let episodeNum = episodeID + 1
        let urlString = "https://api.themoviedb.org/3/tv/\(tmdbID)/season/\(season)/episode/\(episodeNum)?api_key=738b4edd0a156cc126dc4a4b8aea4aca"
        
        guard let url = URL(string: urlString) else { return }
        
        let tmdbImageWidth = UserDefaults.standard.string(forKey: "tmdbImageWidth") ?? "original"
        
        URLSession.custom.dataTask(with: url) { data, _, error in
            guard let data = data, error == nil else { return }
            
            do {
                if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] {
                    let name = json["name"] as? String ?? ""
                    let stillPath = json["still_path"] as? String
                    
                    let imageUrl = stillPath.map { path in
                        tmdbImageWidth == "original"
                        ? "https://image.tmdb.org/t/p/original\(path)"
                        : "https://image.tmdb.org/t/p/w\(tmdbImageWidth)\(path)"
                    } ?? ""
                    
                    DispatchQueue.main.async {
                        self.episodeTitle = name
                        self.episodeImageUrl = imageUrl
                        self.isLoading = false
                    }
                }
            } catch {
                Logger.shared.log("Failed to parse TMDB episode details: \(error.localizedDescription)", type: "Error")
                DispatchQueue.main.async {
                    self.isLoading = false
                }
            }
        }.resume()
    }
    
    func handleFetchFailure(error: Error) {
        Logger.shared.log("Episode details fetch error: \(error.localizedDescription)", type: "Error")
        
        DispatchQueue.main.async {
            if self.retryAttempts < self.maxRetryAttempts {
                self.retryAttempts += 1
                let backoffDelay = self.initialBackoffDelay * pow(2.0, Double(self.retryAttempts - 1))
                
                Logger.shared.log("Will retry episode details fetch in \(backoffDelay) seconds", type: "Debug")
                
                DispatchQueue.main.asyncAfter(deadline: .now() + backoffDelay) {
                    self.fetchAnimeEpisodeDetails()
                }
            } else {
                Logger.shared.log("Failed to fetch episode details after \(self.maxRetryAttempts) attempts", type: "Error")
                self.isLoading = false
                self.retryAttempts = 0
            }
        }
    }
}

private enum NetworkError: Error {
    case noData
    case invalidJSON
    
    var localizedDescription: String {
        switch self {
        case .noData:
            return "No data received"
        case .invalidJSON:
            return "Invalid JSON format"
        }
    }
}

private struct ActionButton: View {
    let icon: String
    let label: String
    let color: Color
    let width: CGFloat
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 2) {
                Image(systemName: icon)
                    .font(.title3)
                Text(label)
                    .font(.caption2)
            }
        }
        .foregroundColor(color)
        .frame(width: width)
    }
}

private struct AsyncImageView: View {
    let url: String
    let width: CGFloat
    let height: CGFloat
    
    var body: some View {
        if let url = URL(string: url) {
            LazyImage(url: url) { state in
                if let image = state.imageContainer?.image {
                    Image(uiImage: image)
                        .resizable()
                        .aspectRatio(16/9, contentMode: .fill)
                        .frame(width: width, height: height)
                        .cornerRadius(8)
                } else if state.error != nil {
                    placeholderView
                        .onAppear {
                            Logger.shared.log("Failed to load episode image: \(state.error?.localizedDescription ?? "Unknown error")", type: "Error")
                        }
                } else {
                    placeholderView
                }
            }
        } else {
            placeholderView
        }
    }
    
    private var placeholderView: some View {
        Rectangle()
            .fill(.tertiary)
            .frame(width: width, height: height)
            .cornerRadius(8)
    }
}


