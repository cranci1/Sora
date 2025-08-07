//
//  VideoPlayer.swift
//  Sora
//
//  Created by Francesco on 09/01/25.
//

import UIKit
import AVKit
import Combine
import GroupActivities

class VideoPlayerViewController: UIViewController {
    let module: ScrapingModule
    
    var player: AVPlayer?
    var playerViewController: NormalPlayer?
    var timeObserverToken: Any?
    var streamUrl: String?
    var fullUrl: String = ""
    var subtitles: String = ""
    var aniListID: Int = 0
    var headers: [String:String]? = nil
    var totalEpisodes: Int = 0
    var tmdbID: Int? = nil
    var isMovie: Bool = false
    var seasonNumber: Int = 1
    var episodeNumber: Int = 0
    var episodeImageUrl: String = ""
    var mediaTitle: String = ""
    
    private var groupSession: GroupSession<VideoWatchingActivity>?
    private var subscriptions = Set<AnyCancellable>()
    private var isLaunchedFromSharePlay = false
    
    private var aniListUpdateSent = false
    private var aniListUpdatedSuccessfully = false
    private var traktUpdateSent = false
    private var traktUpdatedSuccessfully = false
    
    init(module: ScrapingModule) {
        self.module = module
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        configureGroupSession()
        if isLaunchedFromSharePlay {
            return
        }

        setupVideoPlayer()
    }
    
    private func setupVideoPlayer() {
        guard let streamUrl = streamUrl, let url = URL(string: streamUrl) else {
            return
        }
        
        var request = URLRequest(url: url)
        if let mydict = headers, !mydict.isEmpty {
            for (key,value) in mydict {
                request.addValue(value, forHTTPHeaderField: key)
            }
        } else {
            request.addValue("\(module.metadata.baseUrl)", forHTTPHeaderField: "Referer")
            request.addValue("\(module.metadata.baseUrl)", forHTTPHeaderField: "Origin")
        }
        request.addValue("Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/134.0.0.0 Safari/537.36", forHTTPHeaderField: "User-Agent")
        
        let asset = AVURLAsset(url: url, options: ["AVURLAssetHTTPHeaderFieldsKey": request.allHTTPHeaderFields ?? [:]])
        let playerItem = AVPlayerItem(asset: asset)
        
        player = AVPlayer(playerItem: playerItem)
        
        playerViewController = NormalPlayer()
        playerViewController?.player = player
        
        if let playerViewController = playerViewController {
            addChild(playerViewController)
            playerViewController.view.frame = view.bounds
            playerViewController.view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
            view.addSubview(playerViewController.view)
            playerViewController.didMove(toParent: self)
        }
        
        addPeriodicTimeObserver(fullURL: fullUrl)
        let lastPlayedTime = UserDefaults.standard.double(forKey: "lastPlayedTime_\(fullUrl)")
        if lastPlayedTime > 0 {
            let seekTime = CMTime(seconds: lastPlayedTime, preferredTimescale: 1)
            self.player?.seek(to: seekTime) { _ in
                self.player?.play()
            }
        } else {
            self.player?.play()
        }
    }
    
    private func configureGroupSession() {
        Task {
            for await groupSession in VideoWatchingActivity.sessions() {
                await configureGroupSession(groupSession)
            }
        }
    }
    
    @MainActor
    private func configureGroupSession(_ groupSession: GroupSession<VideoWatchingActivity>) async {
        self.groupSession = groupSession

        let activity = groupSession.activity
        
        if streamUrl == nil {
            streamUrl = activity.streamUrl
            fullUrl = activity.fullUrl
            subtitles = activity.subtitles
            aniListID = activity.aniListID
            headers = activity.headers
            totalEpisodes = activity.totalEpisodes
            tmdbID = activity.tmdbID
            isMovie = activity.isMovie
            seasonNumber = activity.seasonNumber
            episodeNumber = activity.episodeNumber
            episodeImageUrl = activity.episodeImageUrl
            mediaTitle = activity.mediaTitle
            
            isLaunchedFromSharePlay = true
            
            setupVideoPlayer()
        }
        
        groupSession.$state
            .receive(on: DispatchQueue.main)
            .sink { [weak self] state in
                switch state {
                case .joined:
                    self?.coordinatePlayback()
                    Logger.shared.log("Joined SharePlay session", type: "SharePlay")
                case .invalidated:
                    self?.groupSession = nil
                    Logger.shared.log("SharePlay session invalidated", type: "SharePlay")
                default:
                    break
                }
            }
            .store(in: &subscriptions)
        
        groupSession.join()
        Logger.shared.log("Automatically joining SharePlay session for: \(activity.mediaTitle)", type: "SharePlay")
    }
    
    private func coordinatePlayback() {
        guard let player = player, let groupSession = groupSession else { return }
        
        player.playbackCoordinator.coordinateWithSession(groupSession)
    }
    
    @MainActor
    func startSharePlay() async {
        guard let streamUrl = streamUrl else { return }
        
        var episodeImageData: Data?
        if !episodeImageUrl.isEmpty, let imageUrl = URL(string: episodeImageUrl) {
            do {
                episodeImageData = try await URLSession.shared.data(from: imageUrl).0
            } catch {
                Logger.shared.log("Failed to load episode image: \(error)", type: "Error")
            }
        }
        
        let activity = VideoWatchingActivity(
            mediaTitle: mediaTitle,
            episodeNumber: episodeNumber,
            streamUrl: streamUrl,
            subtitles: subtitles,
            aniListID: aniListID,
            fullUrl: fullUrl,
            headers: headers,
            episodeImageUrl: episodeImageUrl,
            episodeImageData: episodeImageData,
            totalEpisodes: totalEpisodes,
            tmdbID: tmdbID,
            isMovie: isMovie,
            seasonNumber: seasonNumber
        )
        
        do {
            _ = try await activity.activate()
            Logger.shared.log("SharePlay session started successfully", type: "SharePlay")
        } catch {
            Logger.shared.log("Failed to start SharePlay: \(error)", type: "Error")
            
            let alert = UIAlertController(
                title: "SharePlay Unavailable",
                message: "SharePlay is not available right now. Make sure you're connected to FaceTime or have SharePlay enabled in Control Center.",
                preferredStyle: .alert
            )
            alert.addAction(UIAlertAction(title: "OK", style: .default))
            present(alert, animated: true)
        }
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        if !isLaunchedFromSharePlay {
            player?.play()
            setInitialPlayerRate()
            
            Task {
                await checkForFaceTimeAndPromptSharePlay()
            }
        } else {
            setInitialPlayerRate()
        }
    }
    
    @MainActor
    private func checkForFaceTimeAndPromptSharePlay() async {
        let activity = VideoWatchingActivity(
            mediaTitle: mediaTitle,
            episodeNumber: episodeNumber,
            streamUrl: streamUrl ?? "",
            subtitles: subtitles,
            aniListID: aniListID,
            fullUrl: fullUrl,
            headers: headers,
            episodeImageUrl: episodeImageUrl,
            episodeImageData: nil,
            totalEpisodes: totalEpisodes,
            tmdbID: tmdbID,
            isMovie: isMovie,
            seasonNumber: seasonNumber
        )
        
        let result = await activity.prepareForActivation()
        if result == .activationPreferred {
            showSharePlayPrompt()
        }
    }
    
    @MainActor
    private func showSharePlayPrompt() {
        let alert = UIAlertController(
            title: "Watch Together?",
            message: "You're in a FaceTime call. Would you like to share this video with everyone?",
            preferredStyle: .alert
        )
        
        alert.addAction(UIAlertAction(title: "Share Video", style: .default) { [weak self] _ in
            Task {
                await self?.startSharePlay()
            }
        })
        
        alert.addAction(UIAlertAction(title: "Watch Alone", style: .cancel))
        
        present(alert, animated: true)
    }
    
    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        if let playbackSpeed = player?.rate {
            UserDefaults.standard.set(playbackSpeed, forKey: "lastPlaybackSpeed")
        }
        player?.pause()
        if let timeObserverToken = timeObserverToken {
            player?.removeTimeObserver(timeObserverToken)
            self.timeObserverToken = nil
        }
    }
    
    private func setInitialPlayerRate() {
        if UserDefaults.standard.bool(forKey: "rememberPlaySpeed") {
            let lastPlayedSpeed = UserDefaults.standard.float(forKey: "lastPlaybackSpeed")
            player?.rate = lastPlayedSpeed > 0 ? lastPlayedSpeed : 1.0
        }
    }
    
    func addPeriodicTimeObserver(fullURL: String) {
        guard let player = self.player else { return }
        
        let interval = CMTime(seconds: 1.0, preferredTimescale: CMTimeScale(NSEC_PER_SEC))
        timeObserverToken = player.addPeriodicTimeObserver(forInterval: interval, queue: .main) { [weak self] time in
            guard let self = self,
                  let currentItem = player.currentItem,
                  currentItem.duration.seconds.isFinite else {
                return
            }
            
            let currentTime = time.seconds
            let duration = currentItem.duration.seconds
            
            UserDefaults.standard.set(currentTime, forKey: "lastPlayedTime_\(fullURL)")
            UserDefaults.standard.set(duration, forKey: "totalTime_\(fullURL)")
            
            if let streamUrl = self.streamUrl {
                let progress = min(max(currentTime / duration, 0), 1.0)
                
                let item = ContinueWatchingItem(
                    id: UUID(),
                    imageUrl: self.episodeImageUrl,
                    episodeNumber: self.episodeNumber,
                    mediaTitle: self.mediaTitle,
                    progress: progress,
                    streamUrl: streamUrl,
                    fullUrl: self.fullUrl,
                    subtitles: self.subtitles,
                    aniListID: self.aniListID,
                    module: self.module,
                    headers: self.headers,
                    totalEpisodes: self.totalEpisodes,
                    episodeTitle: "", 
                    seasonNumber: self.seasonNumber
                )
                ContinueWatchingManager.shared.save(item: item)
            }
            
            let remainingPercentage = (duration - currentTime) / duration
            let remainingTimePercentage = UserDefaults.standard.object(forKey: "remainingTimePercentage") != nil ? UserDefaults.standard.double(forKey: "remainingTimePercentage") : 90.0
            let threshold = (100.0 - remainingTimePercentage) / 100.0
            
            if remainingPercentage <= threshold {
                if self.aniListID != 0 && !self.aniListUpdateSent {
                    self.sendAniListUpdate()
                }
                
                if let tmdbId = self.tmdbID, tmdbId > 0, !self.traktUpdateSent {
                    self.sendTraktUpdate(tmdbId: tmdbId)
                }
            }
        }
    }
    
    private func sendAniListUpdate() {
        guard !aniListUpdateSent else { return }
        
        aniListUpdateSent = true
        let aniListMutation = AniListMutation()
        
        aniListMutation.updateAnimeProgress(animeId: self.aniListID, episodeNumber: self.episodeNumber) { [weak self] result in
            switch result {
            case .success:
                self?.aniListUpdatedSuccessfully = true
                Logger.shared.log("Successfully updated AniList progress for Episode \(self?.episodeNumber ?? 0)", type: "General")
            case .failure(let error):
                Logger.shared.log("Failed to update AniList progress: \(error.localizedDescription)", type: "Error")
            }
        }
    }
    
    private func sendTraktUpdate(tmdbId: Int) {
        guard !traktUpdateSent else { return }
        traktUpdateSent = true
        
        let traktMutation = TraktMutation()
        
        if self.isMovie {
            traktMutation.markAsWatched(type: "movie", tmdbID: tmdbId) { [weak self] result in
                switch result {
                case .success:
                    self?.traktUpdatedSuccessfully = true
                    Logger.shared.log("Successfully updated Trakt progress for movie (TMDB: \(tmdbId))", type: "General")
                case .failure(let error):
                    Logger.shared.log("Failed to update Trakt progress for movie: \(error.localizedDescription)", type: "Error")
                }
            }
        } else {
            guard self.episodeNumber > 0 && self.seasonNumber > 0 else {
                Logger.shared.log("Invalid episode (\(self.episodeNumber)) or season (\(self.seasonNumber)) number for Trakt update", type: "Error")
                return
            }
            
            traktMutation.markAsWatched(
                type: "episode",
                tmdbID: tmdbId,
                episodeNumber: self.episodeNumber,
                seasonNumber: self.seasonNumber
            ) { [weak self] result in
                switch result {
                case .success:
                    self?.traktUpdatedSuccessfully = true
                    Logger.shared.log("Successfully updated Trakt progress for Episode \(self?.episodeNumber ?? 0) (TMDB: \(tmdbId))", type: "General")
                case .failure(let error):
                    Logger.shared.log("Failed to update Trakt progress for episode: \(error.localizedDescription)", type: "Error")
                }
            }
        }
    }
    
    override var supportedInterfaceOrientations: UIInterfaceOrientationMask {
        if UserDefaults.standard.bool(forKey: "alwaysLandscape") {
            return .landscape
        } else {
            return .all
        }
    }
    
    override var prefersHomeIndicatorAutoHidden: Bool {
        return true
    }
    
    override var prefersStatusBarHidden: Bool {
        return true
    }
    
    deinit {
        player?.pause()
        if let timeObserverToken = timeObserverToken {
            player?.removeTimeObserver(timeObserverToken)
        }
        
        groupSession?.leave()
        subscriptions.removeAll()
    }
}
