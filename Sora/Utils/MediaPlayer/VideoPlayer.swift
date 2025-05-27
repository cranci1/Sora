//
//  VideoPlayer.swift
//  Sora
//
//  Created by Francesco on 09/01/25.
//

import UIKit
import AVKit
import MediaPlayer
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
    var episodeNumber: Int = 0
    var episodeImageUrl: String = ""
    var mediaTitle: String = ""
    
    private var currentArtwork: MPMediaItemArtwork?
    private var groupSession: GroupSession<WatchTogetherActivity>?
    private var messenger: GroupSessionMessenger?
    
    init(module: ScrapingModule) {
        self.module = module
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        setupSharePlay()
        setupNowPlaying()
        setupRemoteTransportControls()
        
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
        player?.allowsExternalPlayback = false
        
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .moviePlayback)
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            print("Failed to set audio session category: \(error)")
        }
        
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
    
    private func setupSharePlay() {
        guard let streamUrl = streamUrl else { return }
        
        let activity = WatchTogetherActivity(
            streamUrl: streamUrl,
            mediaTitle: mediaTitle,
            episodeNumber: episodeNumber
        )
        
        Task {
            switch await activity.prepareForActivation() {
            case .activationPreferred:
                do {
                    _ = try await activity.activate()
                    Logger.shared.log("SharePlay session activated successfully", type: "General")
                } catch {
                    Logger.shared.log("Failed to activate SharePlay: \(error)", type: "Error")
                }
            case .activationDisabled:
                Logger.shared.log("SharePlay activation disabled", type: "General")
            case .cancelled:
                Logger.shared.log("SharePlay activation cancelled", type: "General")
            @unknown default:
                Logger.shared.log("SharePlay activation unknown state", type: "Info")
            }
        }
        
        Task {
            for await session in WatchTogetherActivity.sessions() {
                configureGroupSession(session)
            }
        }
    }
    
    private func configureGroupSession(_ session: GroupSession<WatchTogetherActivity>) {
        groupSession = session
        messenger = GroupSessionMessenger(session: session)
        
        session.join()
        
        Task {
            guard let messenger = messenger else { return }
            for await (timeString, _) in messenger.messages(of: String.self) {
                if let seconds = Double(timeString) {
                    let time = CMTime(seconds: seconds, preferredTimescale: 600)
                    await handlePlaybackMessage(time)
                }
            }
        }
        
        player?.addPeriodicTimeObserver(
            forInterval: CMTime(seconds: 1, preferredTimescale: 600),
            queue: .main
        ) { [weak self] time in
            guard let self = self else { return }
            Task {
                let timeString = String(time.seconds)
                try? await self.messenger?.send(timeString)
            }
        }
    }
    
    private func handlePlaybackMessage(_ time: CMTime) async {
        await MainActor.run {
            guard let player = player else { return }
            let currentTime = player.currentTime()
            let difference = abs(CMTimeSubtract(time, currentTime).seconds)
            
            if difference > 1.0 {
                player.seek(to: time)
            }
        }
    }
    
    private func setupNowPlaying() {
        var nowPlayingInfo: [String: Any] = [
            MPMediaItemPropertyTitle: mediaTitle,
            MPMediaItemPropertyArtist: "Episode \(episodeNumber)",
            MPNowPlayingInfoPropertyPlaybackRate: player?.rate ?? 1.0
        ]
        
        if let player = player, let currentItem = player.currentItem {
            nowPlayingInfo[MPNowPlayingInfoPropertyElapsedPlaybackTime] = currentItem.currentTime().seconds
            nowPlayingInfo[MPMediaItemPropertyPlaybackDuration] = currentItem.duration.seconds
        }
        
        MPNowPlayingInfoCenter.default().nowPlayingInfo = nowPlayingInfo
        
        if let imageUrl = URL(string: episodeImageUrl) {
            URLSession.custom.dataTask(with: imageUrl) { [weak self] data, _, _ in
                guard let self = self,
                      let data = data,
                      let image = UIImage(data: data) else { return }
                
                DispatchQueue.main.async {
                    self.currentArtwork = MPMediaItemArtwork(boundsSize: image.size) { _ in
                        return image
                    }
                    self.updateNowPlayingInfo()
                }
            }.resume()
        }
        
        let interval = CMTime(seconds: 0.5, preferredTimescale: CMTimeScale(NSEC_PER_SEC))
        player?.addPeriodicTimeObserver(forInterval: interval, queue: .main) { [weak self] _ in
            self?.updateNowPlayingInfo()
        }
    }
    
    func updateNowPlayingInfo() {
        guard let player = player,
              let currentItem = player.currentItem else { return }
        
        var nowPlayingInfo: [String: Any] = [
            MPMediaItemPropertyTitle: mediaTitle,
            MPMediaItemPropertyArtist: "Episode \(episodeNumber)",
            MPNowPlayingInfoPropertyElapsedPlaybackTime: currentItem.currentTime().seconds,
            MPMediaItemPropertyPlaybackDuration: currentItem.duration.seconds,
            MPNowPlayingInfoPropertyPlaybackRate: player.rate
        ]
        
        if let artwork = currentArtwork {
            nowPlayingInfo[MPMediaItemPropertyArtwork] = artwork
        }
        
        MPNowPlayingInfoCenter.default().nowPlayingInfo = nowPlayingInfo
    }
    
    private func setupRemoteTransportControls() {
        let commandCenter = MPRemoteCommandCenter.shared()
        
        commandCenter.playCommand.addTarget { [weak self] _ in
            self?.player?.play()
            self?.updateNowPlayingInfo()
            return .success
        }
        
        commandCenter.pauseCommand.addTarget { [weak self] _ in
            self?.player?.pause()
            self?.updateNowPlayingInfo()
            return .success
        }
        
        commandCenter.seekForwardCommand.isEnabled = false
        commandCenter.seekBackwardCommand.isEnabled = false
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        player?.play()
        setInitialPlayerRate()
    }
    
    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        groupSession?.leave()
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
                    totalEpisodes: self.totalEpisodes
                )
                ContinueWatchingManager.shared.save(item: item)
            }
            
            let remainingPercentage = (duration - currentTime) / duration
            
            if remainingPercentage < 0.1 && self.aniListID != 0 {
                let aniListMutation = AniListMutation()
                aniListMutation.updateAnimeProgress(animeId: self.aniListID, episodeNumber: self.episodeNumber) { result in
                    switch result {
                    case .success:
                        Logger.shared.log("Successfully updated AniList progress for episode \(self.episodeNumber)", type: "General")
                    case .failure(let error):
                        Logger.shared.log("Failed to update AniList progress: \(error.localizedDescription)", type: "Error")
                    }
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
        groupSession?.leave()
        player?.pause()
        if let timeObserverToken = timeObserverToken {
            player?.removeTimeObserver(timeObserverToken)
        }
        MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
    }
}
