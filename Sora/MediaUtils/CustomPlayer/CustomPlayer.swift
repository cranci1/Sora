//
//  CustomPlayer.swift
//  test2
//
//  Created by Francesco on 23/02/25.
//

import UIKit
import AVKit
import SwiftUI
import MediaPlayer
import AVFoundation
import MarqueeLabel

class CustomMediaPlayerViewController: UIViewController, UIGestureRecognizerDelegate {
    private var airplayButton: AVRoutePickerView!
    let module: ScrapingModule
    let streamURL: String
    let fullUrl: String
    let titleText: String
    let episodeNumber: Int
    let episodeImageUrl: String
    let subtitlesURL: String?
    let onWatchNext: () -> Void
    let aniListID: Int
    var headers: [String:String]? = nil
    var tmdbID: Int? = nil
    var isMovie: Bool = false
    var seasonNumber: Int = 1
    
    private var aniListUpdatedSuccessfully = false
    private var aniListUpdateImpossible: Bool = false
    private var aniListRetryCount = 0
    private let aniListMaxRetries = 6
    private let totalEpisodes: Int
    
    private var traktUpdateSent = false
    private var traktUpdatedSuccessfully = false
    
    var player: AVPlayer!
    var timeObserverToken: Any?
    var inactivityTimer: Timer?
    var updateTimer: Timer?
    var originalRate: Float = 1.0
    var holdGesture: UILongPressGestureRecognizer?
    
    var isPlaying = true
    var currentTimeVal: Double = 0.0
    var duration: Double = 0.0
    var isVideoLoaded = false
    
    private var isHoldPauseEnabled: Bool {
        UserDefaults.standard.bool(forKey: "holdForPauseEnabled")
    }
    
    private var isSkip85Visible: Bool {
        if UserDefaults.standard.object(forKey: "skip85Visible") == nil {
            return true
        }
        return UserDefaults.standard.bool(forKey: "skip85Visible")
    }
    
    private var isDoubleTapSkipEnabled: Bool {
        if UserDefaults.standard.object(forKey: "doubleTapSeekEnabled") == nil {
            return false
        }
        return UserDefaults.standard.bool(forKey: "doubleTapSeekEnabled")
    }
    
    private var isPipAutoEnabled: Bool {
        UserDefaults.standard.bool(forKey: "pipAutoEnabled")
    }
    
    private var isPipButtonVisible: Bool {
        if UserDefaults.standard.object(forKey: "pipButtonVisible") == nil {
            return true
        }
        return UserDefaults.standard.bool(forKey: "pipButtonVisible")
    }
    
    private var isAutoplayEnabled: Bool {
        if UserDefaults.standard.object(forKey: "autoplayNext") == nil {
            return true
        }
        return UserDefaults.standard.bool(forKey: "autoplayNext")
    }
    private var pipController: AVPictureInPictureController?
    private var pipButton: UIButton!
    
    var portraitButtonVisibleConstraints: [NSLayoutConstraint] = []
    var portraitButtonHiddenConstraints: [NSLayoutConstraint] = []
    var landscapeButtonVisibleConstraints: [NSLayoutConstraint] = []
    var landscapeButtonHiddenConstraints: [NSLayoutConstraint] = []
    var currentMarqueeConstraints: [NSLayoutConstraint] = []
    
    var subtitleForegroundColor: String = "white"
    var subtitleBackgroundEnabled: Bool = true
    var subtitleFontSize: Double = 20.0
    var subtitleShadowRadius: Double = 1.0
    var subtitlesLoader = VTTSubtitlesLoader()
    var subtitleStackView: UIStackView!
    var subtitleLabels: [UILabel] = []
    var subtitlesEnabled: Bool = true {
        didSet {
            subtitleStackView.isHidden = !subtitlesEnabled
        }
    }
    
    var playerViewController: AVPlayerViewController!
    var controlsContainerView: UIView!
    var playPauseButton: UIImageView!
    var backwardButton: UIImageView!
    var forwardButton: UIImageView!
    var topSubtitleLabel: UILabel!
    var dismissButton: UIButton!
    var menuButton: UIButton!
    var watchNextButton: UIButton!
    var watchNextIconButton: UIButton!
    var blackCoverView: UIView!
    var speedButton: UIButton!
    var skip85Button: UIButton!
    var qualityButton: UIButton!
    var holdSpeedIndicator: UIButton!
    private var lockButton: UIButton!
    private var controlButtonsContainer: GradientBlurButton!
    
    private var unlockButton: UIButton!
    
    var isHLSStream: Bool = false
    var qualities: [(String, String)] = []
    var currentQualityURL: URL?
    var baseM3U8URL: URL?
    
    var sliderHostingController: UIHostingController<MusicProgressSlider<Double>>?
    var sliderViewModel = SliderViewModel()
    var isSliderEditing = false
    
    var watchNextButtonNormalConstraints: [NSLayoutConstraint] = []
    var watchNextButtonControlsConstraints: [NSLayoutConstraint] = []
    var isControlsVisible = false
    
    private var subtitleBottomToSliderConstraint: NSLayoutConstraint?
    private var subtitleBottomToSafeAreaConstraint: NSLayoutConstraint?
    var subtitleBottomPadding: CGFloat = 10.0 {
        didSet {
            updateSubtitleLabelConstraints()
        }
    }
    
    private var wasPlayingBeforeSeek = false
    
    private var malID: Int?
    private var skipIntervals: (op: CMTimeRange?, ed: CMTimeRange?) = (nil, nil)
    
    private var skipIntroButton: UIButton!
    private var skipOutroButton: UIButton!
    private let skipButtonBaseAlpha: CGFloat = 0.9
    @Published var segments: [ClosedRange<Double>] = []
    private var skipIntroLeading: NSLayoutConstraint!
    private var skipOutroLeading: NSLayoutConstraint!
    private var originalIntroLeading: CGFloat = 0
    private var originalOutroLeading: CGFloat = 0
    private var skipIntroDismissedInSession = false
    private var skipOutroDismissedInSession = false
    
    private var playerItemKVOContext = 0
    private var loadedTimeRangesObservation: NSKeyValueObservation?
    private var playerTimeControlStatusObserver: NSKeyValueObservation?
    private var playerRateObserver: NSKeyValueObservation?
    
    private var controlsLocked = false
    private var lockButtonTimer: Timer?
    
    private var isDimmed = false
    private var dimButton: UIButton!
    private var dimButtonToSlider: NSLayoutConstraint!
    private var dimButtonToRight: NSLayoutConstraint!
    private var dimButtonTimer: Timer?
    
    let cfg = UIImage.SymbolConfiguration(pointSize: 15, weight: .medium)
    let bottomControlsCfg = UIImage.SymbolConfiguration(pointSize: 15, weight: .regular)
    
    private var controlsToHide: [UIView] {
        var views = [
            dismissButton,
            playPauseButton,
            backwardButton,
            forwardButton,
            sliderHostingController?.view,
            skip85Button,
            controlButtonsContainer,
            volumeSliderHostingView,
            pipButton,
            airplayButton,
            timeBatteryContainer,
            endTimeIcon,
            endTimeLabel,
            endTimeSeparator,
            lockButton,
            dimButton,
            titleStackView,
            titleLabel,
            episodeNumberLabel,
            controlsContainerView
        ].compactMap { $0 }.filter { $0.superview != nil }
        
        if let airplayParent = airplayButton?.superview {
            views.append(airplayParent)
        }
        
        views.append(contentsOf: view.subviews.filter {
            $0 is UIVisualEffectView ||
            ($0.layer.cornerRadius > 0 && $0 != dismissButton && $0 != lockButton && $0 != dimButton && $0 != pipButton && $0 != holdSpeedIndicator && $0 != volumeSliderHostingView)
        })
        
        return views
    }
    
    private var originalHiddenStates: [UIView: Bool] = [:]
    
    private var volumeObserver: NSKeyValueObservation?
    private var audioSession = AVAudioSession.sharedInstance()
    private var hiddenVolumeView = MPVolumeView(frame: .zero)
    private var systemVolumeSlider: UISlider?
    private var volumeValue: Double = 0.0
    private var volumeViewModel = VolumeViewModel()
    var volumeSliderHostingView: UIView?
    private var subtitleDelay: Double = 0.0
    var currentPlaybackSpeed: Float = 1.0
    
    private var wasPlayingBeforeBackground = false
    private var backgroundToken: Any?
    private var foregroundToken: Any?
    
    private var timeBatteryContainer: UIView?
    private var timeLabel: UILabel?
    private var batteryLabel: UILabel?
    private var timeUpdateTimer: Timer?
    private var endTimeLabel: UILabel?
    private var endTimeIcon: UIImageView?
    private var endTimeSeparator: UIView?
    private var isEndTimeVisible: Bool = false
    
    private var titleStackAboveSkipButtonConstraints: [NSLayoutConstraint] = []
    private var titleStackAboveSliderConstraints: [NSLayoutConstraint] = []
    
    var episodeNumberLabel: UILabel!
    var titleLabel: MarqueeLabel!
    var titleStackView: UIStackView!
    
    private var controlButtonsContainerBottomConstraint: NSLayoutConstraint?
    
    private var isMenuOpen = false
    private var menuProtectionTimer: Timer?
    
    init(module: ScrapingModule,
         urlString: String,
         fullUrl: String,
         title: String,
         episodeNumber: Int,
         onWatchNext: @escaping () -> Void,
         subtitlesURL: String?,
         aniListID: Int,
         totalEpisodes: Int,
         episodeImageUrl: String,headers:[String:String]?) {
        
        self.module = module
        self.streamURL = urlString
        self.fullUrl = fullUrl
        self.titleText = title
        self.episodeNumber = episodeNumber
        self.episodeImageUrl = episodeImageUrl
        self.onWatchNext = onWatchNext
        self.subtitlesURL = subtitlesURL
        self.aniListID = aniListID
        self.headers = headers
        self.totalEpisodes = totalEpisodes
        
        super.init(nibName: nil, bundle: nil)
        
        guard let url = URL(string: urlString) else {
            fatalError("Invalid URL string")
        }
        
        let asset: AVURLAsset
        if url.scheme == "file" {
            Logger.shared.log("Loading local file: \(url.absoluteString)", type: "Debug")
            
            if FileManager.default.fileExists(atPath: url.path) {
                Logger.shared.log("Local file exists at path: \(url.path)", type: "Debug")
            } else {
                Logger.shared.log("WARNING: Local file does not exist at path: \(url.path)", type: "Error")
            }
            
            asset = AVURLAsset(url: url)
        } else {
            Logger.shared.log("Loading remote URL: \(url.absoluteString)", type: "Debug")
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
            
            asset = AVURLAsset(url: url, options: ["AVURLAssetHTTPHeaderFieldsKey": request.allHTTPHeaderFields ?? [:]])
        }
        
        let playerItem = AVPlayerItem(asset: asset)
        self.player = AVPlayer(playerItem: playerItem)
        playerItem.addObserver(self, forKeyPath: "status", options: [.new], context: &playerItemKVOContext)
        
        Logger.shared.log("Created AVPlayerItem with status: \(playerItem.status.rawValue)", type: "Debug")
        
        let lastPlayedTime = UserDefaults.standard.double(forKey: "lastPlayedTime_\(fullUrl)")
        if lastPlayedTime > 0 {
            let seekTime = CMTime(seconds: lastPlayedTime, preferredTimescale: 1)
            self.player.seek(to: seekTime)
        }
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black
        
        skipOutroDismissedInSession = false
        skipIntroDismissedInSession = false
        
        setupHoldGesture()
        loadSubtitleSettings()
        setupPlayerViewController()
        setupControls()
        addInvisibleControlOverlays()
        setupWatchNextButton()
        setupSubtitleLabel()
        setupDismissButton()
        volumeSlider()
        setupDimButton()
        setupSpeedButton()
        setupQualityButton()
        setupMenuButton()
        setupMarqueeLabel()
        setupSkip85Button()
        setupSkipButtons()
        setupSkipAndDismissGestures()
        addTimeObserver()
        startUpdateTimer()
        setupLockButton()
        setupUnlockButton()
        setupAudioSession()
        updateSkipButtonsVisibility()
        setupHoldSpeedIndicator()
        setupPipIfSupported()
        setupTimeBatteryIndicator()
        setupTopRowLayout()
        updateSkipButtonsVisibility()
        
        if !isSkip85Visible {
            skip85Button.isHidden = true
            skip85Button.alpha = 0.0
        }
        
        updateTitleVisibilityForCurrentOrientation()
        
        isControlsVisible = true
        for control in controlsToHide {
            control.alpha = 1.0
        }
        
        if let volumeSlider = volumeSliderHostingView {
            volumeSlider.alpha = 1.0
            volumeSlider.isHidden = false
            view.bringSubviewToFront(volumeSlider)
        }
        
        setupControlButtonsContainer()
        
        view.bringSubviewToFront(subtitleStackView)
        subtitleStackView.isHidden = !SubtitleSettingsManager.shared.settings.enabled
        
        AniListMutation().fetchMalID(animeId: aniListID) { [weak self] result in
            switch result {
            case .success(let mal):
                self?.malID = mal
                self?.fetchSkipTimes(type: "op")
                self?.fetchSkipTimes(type: "ed")
            case .failure(let error):
                Logger.shared.log("Unable to fetch MAL ID: \(error)",type:"Error")
            }
        }
        
        for control in controlsToHide {
            originalHiddenStates[control] = control.isHidden
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            self?.checkForHLSStream()
        }
        
        do {
            try audioSession.setActive(true)
        } catch {
            Logger.shared.log("Error activating audio session: \(error)", type: "Debug")
        }
        
        playerRateObserver = player.observe(\.rate, options: [.new, .old]) { [weak self] player, change in
            guard let self = self else { return }
            DispatchQueue.main.async {
                let isActuallyPlaying = player.rate != 0
                if self.isPlaying != isActuallyPlaying {
                    self.isPlaying = isActuallyPlaying
                    self.playPauseButton.image = UIImage(systemName: isActuallyPlaying ? "pause.fill" : "play.fill")
                }
            }
        }
        
        volumeViewModel.value = Double(audioSession.outputVolume)
        
        volumeObserver = audioSession.observe(\.outputVolume, options: [.new]) { [weak self] session, change in
            guard let newVol = change.newValue else { return }
            DispatchQueue.main.async {
                self?.volumeViewModel.value = Double(newVol)
                Logger.shared.log("Hardware volume changed, new value: \(newVol)", type: "Debug")
            }
        }
        
#if os(iOS) && !targetEnvironment(macCatalyst)
        if #available(iOS 16.0, *) {
            playerViewController.allowsVideoFrameAnalysis = false
        }
#endif
        
        if let url = subtitlesURL, !url.isEmpty {
            subtitlesLoader.load(from: url)
        }
        
        DispatchQueue.main.async {
            self.isControlsVisible = true
            NSLayoutConstraint.deactivate(self.watchNextButtonNormalConstraints)
            NSLayoutConstraint.activate(self.watchNextButtonControlsConstraints)
            self.watchNextButton.alpha = 1.0
            self.view.layoutIfNeeded()
        }
        
        hiddenVolumeView.showsRouteButton = false
        hiddenVolumeView.isHidden = true
        view.addSubview(hiddenVolumeView)
        
        hiddenVolumeView.translatesAutoresizingMaskIntoConstraints = false
        hiddenVolumeView.widthAnchor.constraint(equalToConstant: 1).isActive = true
        hiddenVolumeView.heightAnchor.constraint(equalToConstant: 1).isActive = true
        hiddenVolumeView.leadingAnchor.constraint(equalTo: view.leadingAnchor).isActive = true
        hiddenVolumeView.topAnchor.constraint(equalTo: view.topAnchor).isActive = true
        
        if let slider = hiddenVolumeView.subviews.first(where: { $0 is UISlider }) as? UISlider {
            systemVolumeSlider = slider
        }
        
        let twoFingerTapGesture = UITapGestureRecognizer(target: self, action: #selector(handleTwoFingerTapPause(_:)))
        twoFingerTapGesture.numberOfTouchesRequired = 2
        twoFingerTapGesture.delegate = self
        view.addGestureRecognizer(twoFingerTapGesture)
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handlePlaybackEnded),
            name: .AVPlayerItemDidPlayToEndTime,
            object: player.currentItem
        )
        
        
    }
    
    private func setupTopRowLayout() {
        if let old = view.subviews.first(where: { $0 is GradientBlurButton && $0 != controlButtonsContainer && $0 != skip85Button }) {
            old.removeFromSuperview()
        }
        
        let capsuleContainer = GradientBlurButton(type: .custom)
        capsuleContainer.translatesAutoresizingMaskIntoConstraints = false
        capsuleContainer.backgroundColor = .clear
        capsuleContainer.layer.cornerRadius = 21
        capsuleContainer.clipsToBounds = true
        view.addSubview(capsuleContainer)
        capsuleContainer.alpha = isControlsVisible ? 1.0 : 0.0
        
        let buttons: [UIView] = [airplayButton, pipButton, lockButton, dimButton]
        for btn in buttons {
            btn.removeFromSuperview()
            capsuleContainer.addSubview(btn)
        }
        
        let forcedLandscape = UserDefaults.standard.bool(forKey: "alwaysLandscape")
        let isLandscape = forcedLandscape || UIDevice.current.orientation.isLandscape || view.bounds.width > view.bounds.height
        
        if isLandscape {
            NSLayoutConstraint.activate([
                capsuleContainer.leadingAnchor.constraint(equalTo: dismissButton.superview!.trailingAnchor, constant: 12),
                capsuleContainer.centerYAnchor.constraint(equalTo: dismissButton.superview!.centerYAnchor),
                capsuleContainer.heightAnchor.constraint(equalToConstant: 42)
            ])
            
            for (index, btn) in buttons.enumerated() {
                NSLayoutConstraint.activate([
                    btn.centerYAnchor.constraint(equalTo: capsuleContainer.centerYAnchor),
                    btn.widthAnchor.constraint(equalToConstant: 40),
                    btn.heightAnchor.constraint(equalToConstant: 40)
                ])
                if index == 0 {
                    btn.leadingAnchor.constraint(equalTo: capsuleContainer.leadingAnchor, constant: 20).isActive = true
                } else {
                    btn.leadingAnchor.constraint(equalTo: buttons[index - 1].trailingAnchor, constant: 18).isActive = true
                }
                if index == buttons.count - 1 {
                    btn.trailingAnchor.constraint(equalTo: capsuleContainer.trailingAnchor, constant: -10).isActive = true
                }
            }
        } else {
            NSLayoutConstraint.activate([
                capsuleContainer.topAnchor.constraint(equalTo: dismissButton.superview!.bottomAnchor, constant: 12),
                capsuleContainer.leadingAnchor.constraint(equalTo: dismissButton.superview!.leadingAnchor),
                capsuleContainer.widthAnchor.constraint(equalToConstant: 42)
            ])
            
            for (index, btn) in buttons.enumerated() {
                NSLayoutConstraint.activate([
                    btn.centerXAnchor.constraint(equalTo: capsuleContainer.centerXAnchor),
                    btn.widthAnchor.constraint(equalToConstant: 40),
                    btn.heightAnchor.constraint(equalToConstant: 40)
                ])
                if index == 0 {
                    btn.topAnchor.constraint(equalTo: capsuleContainer.topAnchor, constant: 20).isActive = true
                } else {
                    btn.topAnchor.constraint(equalTo: buttons[index - 1].bottomAnchor, constant: 18).isActive = true
                }
                if index == buttons.count - 1 {
                    btn.bottomAnchor.constraint(equalTo: capsuleContainer.bottomAnchor, constant: -10).isActive = true
                }
            }
        }
        
        view.bringSubviewToFront(skip85Button)
        
        if let volumeSlider = volumeSliderHostingView {
            view.bringSubviewToFront(volumeSlider)
        }
    }
    
    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        super.viewWillTransition(to: size, with: coordinator)
        
        titleLabel.shutdownLabel()
        
        coordinator.animate(alongsideTransition: { _ in
            self.setupTopRowLayout()
        }, completion: { _ in
            self.updateTitleVisibilityForCurrentOrientation()
            
            self.view.setNeedsLayout()
            self.view.layoutIfNeeded()
        })
    }
    
    private func updateTitleVisibilityForCurrentOrientation() {
        let forcedLandscape = UserDefaults.standard.bool(forKey: "alwaysLandscape")
        let isLandscape = forcedLandscape || UIDevice.current.orientation.isLandscape || view.bounds.width > view.bounds.height
        
        episodeNumberLabel.isHidden = !isLandscape
        titleLabel.isHidden = !isLandscape
        titleStackView.isHidden = !isLandscape
        
        episodeNumberLabel.alpha = isLandscape ? 1.0 : 0.0
        titleLabel.alpha = isLandscape ? 1.0 : 0.0
        titleStackView.alpha = isLandscape ? 1.0 : 0.0
        
        if isLandscape {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                self.titleLabel.restartLabel()
            }
        }
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        if let pipController = pipController {
            pipController.playerLayer.frame = view.bounds
        }
        
        guard let episodeNumberLabel = episodeNumberLabel else {
            return
        }
        
        let availableWidth = episodeNumberLabel.frame.width
        let textWidth = episodeNumberLabel.intrinsicContentSize.width
        
        if textWidth > availableWidth {
            episodeNumberLabel.lineBreakMode = .byTruncatingTail
        } else {
            episodeNumberLabel.lineBreakMode = .byClipping
        }
        
        let forcedLandscape = UserDefaults.standard.bool(forKey: "alwaysLandscape")
        let isLandscape = forcedLandscape || view.bounds.width > view.bounds.height
        let wasLandscape = UserDefaults.standard.bool(forKey: "wasLandscapeOrientation")
        
        if isLandscape != wasLandscape {
            UserDefaults.standard.set(isLandscape, forKey: "wasLandscapeOrientation")
            resetMarqueeAfterOrientationChange()
            setupTopRowLayout()
        } else {
            updateMarqueeConstraintsForBottom()
        }
        
        updateTitleVisibilityForCurrentOrientation()
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        player?.play()
        setInitialPlayerRate()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        NotificationCenter.default.addObserver(self, selector: #selector(playerItemDidChange), name: .AVPlayerItemNewAccessLogEntry, object: nil)
        skip85Button?.isHidden = !isSkip85Visible
        if !isSkip85Visible {
            skip85Button?.alpha = 0.0
        }
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        if let playbackSpeed = player?.rate {
            UserDefaults.standard.set(playbackSpeed, forKey: "lastPlaybackSpeed")
        }
        
        if let token = timeObserverToken {
            player.removeTimeObserver(token)
            timeObserverToken = nil
        }
        
        loadedTimeRangesObservation?.invalidate()
        loadedTimeRangesObservation = nil
        
        updateTimer?.invalidate()
        inactivityTimer?.invalidate()
        
        player.pause()
    }
    
    deinit {
        if let timeUpdateTimer = timeUpdateTimer {
            timeUpdateTimer.invalidate()
        }
        
        menuProtectionTimer?.invalidate()
        menuProtectionTimer = nil
        
        NotificationCenter.default.removeObserver(self, name: .AVPlayerItemDidPlayToEndTime, object: nil)
        NotificationCenter.default.removeObserver(self)
        UIDevice.current.isBatteryMonitoringEnabled = false
        
        endTimeIcon?.removeFromSuperview()
        endTimeLabel?.removeFromSuperview()
        endTimeSeparator?.removeFromSuperview()
        
        inactivityTimer?.invalidate()
        inactivityTimer = nil
        
        loadedTimeRangesObservation?.invalidate()
        loadedTimeRangesObservation = nil
        volumeObserver?.invalidate()
        volumeObserver = nil
        
        if let token = timeObserverToken {
            player?.removeTimeObserver(token)
        }
        
        if let currentItem = player?.currentItem {
            currentItem.removeObserver(self, forKeyPath: "status", context: &playerItemKVOContext)
        }
        
        player?.replaceCurrentItem(with: nil)
        player?.pause()
        player = nil
        
        if let playerVC = playerViewController {
            playerVC.willMove(toParent: nil)
            playerVC.view.removeFromSuperview()
            playerVC.removeFromParent()
        }
        
        if let sliderHost = sliderHostingController {
            sliderHost.willMove(toParent: nil)
            sliderHost.view.removeFromSuperview()
            sliderHost.removeFromParent()
        }
        
        playerViewController = nil
        sliderHostingController = nil
        volumeSliderHostingView = nil
        
        volumeSliderHostingView?.removeFromSuperview()
        hiddenVolumeView.removeFromSuperview()
        subtitleStackView?.removeFromSuperview()
        episodeNumberLabel?.removeFromSuperview()
        titleLabel?.removeFromSuperview()
        titleStackView?.removeFromSuperview()
        controlsContainerView?.removeFromSuperview()
        blackCoverView?.removeFromSuperview()
        skipIntroButton?.removeFromSuperview()
        skipOutroButton?.removeFromSuperview()
        skip85Button?.removeFromSuperview()
        pipButton?.removeFromSuperview()
        airplayButton?.removeFromSuperview()
        menuButton?.removeFromSuperview()
        speedButton?.removeFromSuperview()
        qualityButton?.removeFromSuperview()
        holdSpeedIndicator?.removeFromSuperview()
        lockButton?.removeFromSuperview()
        dimButton?.removeFromSuperview()
        dismissButton?.removeFromSuperview()
        watchNextButton?.removeFromSuperview()
        
        try? AVAudioSession.sharedInstance().setActive(false)
    }
    
    override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?) {
        guard context == &playerItemKVOContext else {
            super.observeValue(forKeyPath: keyPath, of: object, change: change, context: context)
            return
        }
        
        if keyPath == "status" {
            if let playerItem = object as? AVPlayerItem {
                switch playerItem.status {
                case .readyToPlay:
                    Logger.shared.log("AVPlayerItem status: Ready to play", type: "Debug")
                case .failed:
                    if let error = playerItem.error {
                        Logger.shared.log("AVPlayerItem failed with error: \(error.localizedDescription)", type: "Error")
                        if let nsError = error as NSError? {
                            Logger.shared.log("Error domain: \(nsError.domain), code: \(nsError.code), userInfo: \(nsError.userInfo)", type: "Error")
                        }
                    } else {
                        Logger.shared.log("AVPlayerItem failed with unknown error", type: "Error")
                    }
                case .unknown:
                    Logger.shared.log("AVPlayerItem status: Unknown", type: "Debug")
                @unknown default:
                    Logger.shared.log("AVPlayerItem status: Unknown default case", type: "Debug")
                }
            }
        } else if keyPath == "loadedTimeRanges" {
        }
    }
    
    @objc private func playerItemDidChange() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            if self.qualityButton.isHidden && self.isHLSStream {
                self.qualityButton.isHidden = false
                self.qualityButton.menu = self.qualitySelectionMenu()
                
                UIView.animate(withDuration: 0.25, delay: 0, options: .curveEaseInOut) {
                    self.view.layoutIfNeeded()
                }
            }
        }
    }
    
    private func getSegmentsColor() -> Color {
        if let data = UserDefaults.standard.data(forKey: "segmentsColorData"),
           let uiColor = try? NSKeyedUnarchiver.unarchiveTopLevelObjectWithData(data) as? UIColor {
            return Color(uiColor)
        }
        return .yellow
    }
    
    func setupPlayerViewController() {
        playerViewController = AVPlayerViewController()
        playerViewController.player = player
        playerViewController.showsPlaybackControls = false
        addChild(playerViewController)
        if playerViewController.view.superview == nil {
            view.addSubview(playerViewController.view)
        }
        playerViewController.view.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            playerViewController.view.topAnchor.constraint(equalTo: view.topAnchor),
            playerViewController.view.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            playerViewController.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            playerViewController.view.trailingAnchor.constraint(equalTo: view.trailingAnchor)
        ])
        playerViewController.didMove(toParent: self)
        
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(toggleControls))
        view.addGestureRecognizer(tapGesture)
        
        controlsContainerView = PassthroughView()
        controlsContainerView.backgroundColor = UIColor.black.withAlphaComponent(0.0)
        view.addSubview(controlsContainerView)
        controlsContainerView.translatesAutoresizingMaskIntoConstraints = false
    }
    
    func setupControls() {
        NSLayoutConstraint.activate([
            controlsContainerView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            controlsContainerView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor),
            controlsContainerView.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor),
            controlsContainerView.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor)
        ])
        
        blackCoverView = UIView()
        blackCoverView.backgroundColor = UIColor.black.withAlphaComponent(0.4)
        blackCoverView.translatesAutoresizingMaskIntoConstraints = false
        blackCoverView.isUserInteractionEnabled = false
        blackCoverView.alpha = 0.0
        view.insertSubview(blackCoverView, belowSubview: controlsContainerView)
        NSLayoutConstraint.activate([
            blackCoverView.topAnchor.constraint(equalTo: view.topAnchor),
            blackCoverView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            blackCoverView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            blackCoverView.trailingAnchor.constraint(equalTo: view.trailingAnchor)
        ])
        
        let backwardCircle = createCircularBlurBackground(size: 60)
        controlsContainerView.addSubview(backwardCircle)
        backwardCircle.translatesAutoresizingMaskIntoConstraints = false
        
        let playPauseCircle = createCircularBlurBackground(size: 80)
        controlsContainerView.addSubview(playPauseCircle)
        playPauseCircle.translatesAutoresizingMaskIntoConstraints = false
        
        let forwardCircle = createCircularBlurBackground(size: 60)
        controlsContainerView.addSubview(forwardCircle)
        forwardCircle.translatesAutoresizingMaskIntoConstraints = false
        
        backwardButton = UIImageView(image: UIImage(systemName: "gobackward"))
        backwardButton.tintColor = .white
        backwardButton.contentMode = .scaleAspectFit
        backwardButton.isUserInteractionEnabled = true
        
        let backwardTap = UITapGestureRecognizer(target: self, action: #selector(seekBackward))
        backwardTap.numberOfTapsRequired = 1
        backwardButton.addGestureRecognizer(backwardTap)
        
        let backwardLongPress = UILongPressGestureRecognizer(target: self, action: #selector(seekBackwardLongPress(_:)))
        backwardLongPress.minimumPressDuration = 0.5
        backwardButton.addGestureRecognizer(backwardLongPress)
        backwardTap.require(toFail: backwardLongPress)
        
        controlsContainerView.addSubview(backwardButton)
        backwardButton.translatesAutoresizingMaskIntoConstraints = false
        
        playPauseButton = UIImageView(image: UIImage(systemName: "pause.fill"))
        playPauseButton.tintColor = .white
        playPauseButton.contentMode = .scaleAspectFit
        playPauseButton.isUserInteractionEnabled = true
        
        let playPauseTap = UITapGestureRecognizer(target: self, action: #selector(togglePlayPause))
        playPauseTap.delaysTouchesBegan = false
        playPauseTap.delegate = self
        playPauseButton.addGestureRecognizer(playPauseTap)
        
        
        playPauseButton.addGestureRecognizer(playPauseTap)
        controlsContainerView.addSubview(playPauseButton)
        playPauseButton.translatesAutoresizingMaskIntoConstraints = false
        
        forwardButton = UIImageView(image: UIImage(systemName: "goforward"))
        forwardButton.tintColor = .white
        forwardButton.contentMode = .scaleAspectFit
        forwardButton.isUserInteractionEnabled = true
        
        let forwardTap = UITapGestureRecognizer(target: self, action: #selector(seekForward))
        forwardTap.numberOfTapsRequired = 1
        forwardButton.addGestureRecognizer(forwardTap)
        
        let forwardLongPress = UILongPressGestureRecognizer(target: self, action: #selector(seekForwardLongPress(_:)))
        forwardLongPress.minimumPressDuration = 0.5
        forwardButton.addGestureRecognizer(forwardLongPress)
        
        forwardTap.require(toFail: forwardLongPress)
        
        controlsContainerView.addSubview(forwardButton)
        forwardButton.translatesAutoresizingMaskIntoConstraints = false
        
        let segmentsColor = self.getSegmentsColor()
        
        let sliderView = MusicProgressSlider(
            value: Binding(
                get: { self.sliderViewModel.sliderValue },
                set: { self.sliderViewModel.sliderValue = $0 }
            ),
            inRange: 0...(duration > 0 ? duration : 1.0),
            activeFillColor: .white,
            fillColor: .white,
            textColor: .white.opacity(0.7),
            emptyColor: .white.opacity(0.3),
            height: 33,
            onEditingChanged: { editing in
                if editing {
                    self.isSliderEditing = true
                    
                    self.wasPlayingBeforeSeek = (self.player.timeControlStatus == .playing)
                    self.originalRate = self.player.rate
                    
                    self.player.pause()
                } else {
                    let target = CMTime(seconds: self.sliderViewModel.sliderValue,
                                        preferredTimescale: 600)
                    self.player.seek(
                        to: target,
                        toleranceBefore: .zero,
                        toleranceAfter: .zero
                    ) { [weak self] _ in
                        guard let self = self else { return }
                        
                        let final = self.player.currentTime().seconds
                        self.sliderViewModel.sliderValue = final
                        self.currentTimeVal = final
                        self.isSliderEditing = false
                        
                        if self.wasPlayingBeforeSeek {
                            self.player.playImmediately(atRate: self.originalRate)
                        }
                    }
                }
            },
            introSegments: sliderViewModel.introSegments,
            outroSegments: sliderViewModel.outroSegments,
            introColor: segmentsColor,
            outroColor: segmentsColor
        )
        
        sliderHostingController = UIHostingController(rootView: sliderView)
        guard let sliderHostView = sliderHostingController?.view else { return }
        sliderHostView.backgroundColor = .clear
        sliderHostView.translatesAutoresizingMaskIntoConstraints = false
        controlsContainerView.addSubview(sliderHostView)
        
        NSLayoutConstraint.activate([
            sliderHostView.leadingAnchor.constraint(equalTo: controlsContainerView.leadingAnchor, constant: 18),
            sliderHostView.trailingAnchor.constraint(equalTo: controlsContainerView.trailingAnchor, constant: -18),
            sliderHostView.bottomAnchor.constraint(equalTo: controlsContainerView.bottomAnchor, constant: -20),
            sliderHostView.heightAnchor.constraint(equalToConstant: 30)
        ])
        
        NSLayoutConstraint.activate([
            playPauseCircle.centerXAnchor.constraint(equalTo: controlsContainerView.centerXAnchor),
            playPauseCircle.centerYAnchor.constraint(equalTo: controlsContainerView.centerYAnchor),
            playPauseCircle.widthAnchor.constraint(equalToConstant: 80),
            playPauseCircle.heightAnchor.constraint(equalToConstant: 80),
            
            backwardCircle.centerYAnchor.constraint(equalTo: playPauseCircle.centerYAnchor),
            backwardCircle.trailingAnchor.constraint(equalTo: playPauseCircle.leadingAnchor, constant: -50),
            backwardCircle.widthAnchor.constraint(equalToConstant: 60),
            backwardCircle.heightAnchor.constraint(equalToConstant: 60),
            
            forwardCircle.centerYAnchor.constraint(equalTo: playPauseCircle.centerYAnchor),
            forwardCircle.leadingAnchor.constraint(equalTo: playPauseCircle.trailingAnchor, constant: 50),
            forwardCircle.widthAnchor.constraint(equalToConstant: 60),
            forwardCircle.heightAnchor.constraint(equalToConstant: 60)
        ])
        
        NSLayoutConstraint.activate([
            playPauseButton.centerXAnchor.constraint(equalTo: playPauseCircle.centerXAnchor),
            playPauseButton.centerYAnchor.constraint(equalTo: playPauseCircle.centerYAnchor),
            playPauseButton.widthAnchor.constraint(equalToConstant: 50),
            playPauseButton.heightAnchor.constraint(equalToConstant: 50),
            
            backwardButton.centerXAnchor.constraint(equalTo: backwardCircle.centerXAnchor),
            backwardButton.centerYAnchor.constraint(equalTo: backwardCircle.centerYAnchor),
            backwardButton.widthAnchor.constraint(equalToConstant: 35),
            backwardButton.heightAnchor.constraint(equalToConstant: 35),
            
            forwardButton.centerXAnchor.constraint(equalTo: forwardCircle.centerXAnchor),
            forwardButton.centerYAnchor.constraint(equalTo: forwardCircle.centerYAnchor),
            forwardButton.widthAnchor.constraint(equalToConstant: 35),
            forwardButton.heightAnchor.constraint(equalToConstant: 35)
        ])
    }
    
    private func createCircularBlurBackground(size: CGFloat) -> UIView {
        let blurEffect = UIBlurEffect(style: .systemMaterial)
        let blurView = UIVisualEffectView(effect: blurEffect)
        blurView.translatesAutoresizingMaskIntoConstraints = false
        blurView.layer.cornerRadius = size / 2
        blurView.clipsToBounds = true
        
        let vibrancyEffect = UIVibrancyEffect(blurEffect: blurEffect)
        let vibrancyView = UIVisualEffectView(effect: vibrancyEffect)
        vibrancyView.frame = blurView.bounds
        vibrancyView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        blurView.contentView.addSubview(vibrancyView)
        
        let tintView = UIView()
        tintView.backgroundColor = UIColor.white.withAlphaComponent(0.08)
        tintView.layer.cornerRadius = size / 2
        tintView.clipsToBounds = true
        tintView.translatesAutoresizingMaskIntoConstraints = false
        vibrancyView.contentView.addSubview(tintView)
        NSLayoutConstraint.activate([
            tintView.leadingAnchor.constraint(equalTo: vibrancyView.contentView.leadingAnchor),
            tintView.trailingAnchor.constraint(equalTo: vibrancyView.contentView.trailingAnchor),
            tintView.topAnchor.constraint(equalTo: vibrancyView.contentView.topAnchor),
            tintView.bottomAnchor.constraint(equalTo: vibrancyView.contentView.bottomAnchor)
        ])
        
        NSLayoutConstraint.activate([
            blurView.widthAnchor.constraint(equalToConstant: size),
            blurView.heightAnchor.constraint(equalToConstant: size)
        ])
        
        return blurView
    }
    
    @objc private func handleTwoFingerTapPause(_ gesture: UITapGestureRecognizer) {
        if gesture.state == .ended {
            togglePlayPause()
        }
    }
    
    func addInvisibleControlOverlays() {
        let playPauseOverlay = UIButton(type: .custom)
        playPauseOverlay.backgroundColor = .clear
        playPauseOverlay.addTarget(self, action: #selector(togglePlayPause), for: .touchUpInside)
        view.addSubview(playPauseOverlay)
        playPauseOverlay.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            playPauseOverlay.centerXAnchor.constraint(equalTo: playPauseButton.centerXAnchor),
            playPauseOverlay.centerYAnchor.constraint(equalTo: playPauseButton.centerYAnchor),
            playPauseOverlay.widthAnchor.constraint(equalTo: playPauseButton.widthAnchor, constant: 20),
            playPauseOverlay.heightAnchor.constraint(equalTo: playPauseButton.heightAnchor, constant: 20)
        ])
    }
    
    func setupSkipAndDismissGestures() {
        if isDoubleTapSkipEnabled {
            let doubleTapGesture = UITapGestureRecognizer(target: self, action: #selector(handleDoubleTap(_:)))
            doubleTapGesture.numberOfTapsRequired = 2
            view.addGestureRecognizer(doubleTapGesture)
            
            if let gestures = view.gestureRecognizers {
                for gesture in gestures {
                    if let tapGesture = gesture as? UITapGestureRecognizer, tapGesture.numberOfTapsRequired == 1 {
                        tapGesture.require(toFail: doubleTapGesture)
                    }
                }
            }
        }
        
        let panGesture = UIPanGestureRecognizer(target: self, action: #selector(handlePanGesture(_:)))
        if let introSwipe = skipIntroButton.gestureRecognizers?.first(
            where: { $0 is UISwipeGestureRecognizer && ($0 as! UISwipeGestureRecognizer).direction == .left }
        ),
           let outroSwipe = skipOutroButton.gestureRecognizers?.first(
            where: { $0 is UISwipeGestureRecognizer && ($0 as! UISwipeGestureRecognizer).direction == .left }
           ) {
            panGesture.require(toFail: introSwipe)
            panGesture.require(toFail: outroSwipe)
        }
        
        view.addGestureRecognizer(panGesture)
    }
    
    func showSkipFeedback(direction: String) {
        let diameter: CGFloat = 600
        
        if let existingFeedback = view.viewWithTag(999) {
            existingFeedback.layer.removeAllAnimations()
            existingFeedback.removeFromSuperview()
        }
        
        let circleView = UIView()
        circleView.backgroundColor = UIColor.white.withAlphaComponent(0.0)
        circleView.layer.cornerRadius = diameter / 2
        circleView.clipsToBounds = true
        circleView.translatesAutoresizingMaskIntoConstraints = false
        circleView.isUserInteractionEnabled = false
        circleView.tag = 999
        
        let iconName = (direction == "forward") ? "goforward" : "gobackward"
        let imageView = UIImageView(image: UIImage(systemName: iconName))
        imageView.tintColor = .black
        imageView.contentMode = .scaleAspectFit
        imageView.translatesAutoresizingMaskIntoConstraints = false
        imageView.alpha = 0.8
        
        circleView.addSubview(imageView)
        
        if direction == "forward" {
            NSLayoutConstraint.activate([
                imageView.centerYAnchor.constraint(equalTo: circleView.centerYAnchor),
                imageView.centerXAnchor.constraint(equalTo: circleView.leadingAnchor, constant: diameter / 4),
                imageView.widthAnchor.constraint(equalToConstant: 100),
                imageView.heightAnchor.constraint(equalToConstant: 100)
            ])
        } else {
            NSLayoutConstraint.activate([
                imageView.centerYAnchor.constraint(equalTo: circleView.centerYAnchor),
                imageView.centerXAnchor.constraint(equalTo: circleView.trailingAnchor, constant: -diameter / 4),
                imageView.widthAnchor.constraint(equalToConstant: 100),
                imageView.heightAnchor.constraint(equalToConstant: 100)
            ])
        }
        
        view.addSubview(circleView)
        
        if direction == "forward" {
            NSLayoutConstraint.activate([
                circleView.centerYAnchor.constraint(equalTo: view.centerYAnchor),
                circleView.centerXAnchor.constraint(equalTo: view.trailingAnchor),
                circleView.widthAnchor.constraint(equalToConstant: diameter),
                circleView.heightAnchor.constraint(equalToConstant: diameter)
            ])
        } else {
            NSLayoutConstraint.activate([
                circleView.centerYAnchor.constraint(equalTo: view.centerYAnchor),
                circleView.centerXAnchor.constraint(equalTo: view.leadingAnchor),
                circleView.widthAnchor.constraint(equalToConstant: diameter),
                circleView.heightAnchor.constraint(equalToConstant: diameter)
            ])
        }
        
        UIView.animate(withDuration: 0.2, animations: {
            circleView.backgroundColor = UIColor.white.withAlphaComponent(0.5)
            imageView.alpha = 0.8
        }) { _ in
            UIView.animate(withDuration: 0.5, delay: 0.5, options: [], animations: {
                circleView.backgroundColor = UIColor.white.withAlphaComponent(0.0)
                imageView.alpha = 0.0
            }, completion: { _ in
                circleView.removeFromSuperview()
                imageView.removeFromSuperview()
            })
        }
    }
    
    func setupSubtitleLabel() {
        subtitleStackView = UIStackView()
        subtitleStackView.axis = .vertical
        subtitleStackView.alignment = .center
        subtitleStackView.distribution = .fill
        subtitleStackView.spacing = 2
        
        if let subtitleStackView = subtitleStackView {
            view.addSubview(subtitleStackView)
            subtitleStackView.translatesAutoresizingMaskIntoConstraints = false
            
            subtitleBottomToSliderConstraint = subtitleStackView.bottomAnchor.constraint(
                equalTo: sliderHostingController?.view.topAnchor ?? view.bottomAnchor,
                constant: -20
            )
            
            subtitleBottomToSafeAreaConstraint = subtitleStackView.bottomAnchor.constraint(
                equalTo: view.safeAreaLayoutGuide.bottomAnchor,
                constant: -subtitleBottomPadding
            )
            
            NSLayoutConstraint.activate([
                subtitleStackView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
                subtitleStackView.leadingAnchor.constraint(greaterThanOrEqualTo: view.leadingAnchor, constant: 36),
                subtitleStackView.trailingAnchor.constraint(lessThanOrEqualTo: view.trailingAnchor, constant: -36)
            ])
            
            subtitleBottomToSafeAreaConstraint?.isActive = true
        }
        
        for _ in 0..<2 {
            let label = UILabel()
            label.textAlignment = .center
            label.numberOfLines = 0
            label.font = UIFont.systemFont(ofSize: CGFloat(subtitleFontSize))
            subtitleLabels.append(label)
            subtitleStackView.addArrangedSubview(label)
        }
        
        updateSubtitleLabelAppearance()
    }
    
    func updateSubtitleLabelConstraints() {
        if isControlsVisible {
            subtitleBottomToSliderConstraint?.constant = -20
        } else {
            subtitleBottomToSafeAreaConstraint?.constant = -subtitleBottomPadding
        }
        
        view.setNeedsLayout()
        UIView.animate(withDuration: 0.2) {
            self.view.layoutIfNeeded()
        }
    }
    
    func setupDismissButton() {
        let image = UIImage(systemName: "xmark", withConfiguration: cfg)
        
        let dismissCircle = createCircularBlurBackground(size: 42)
        view.addSubview(dismissCircle)
        dismissCircle.translatesAutoresizingMaskIntoConstraints = false
        
        dismissButton = UIButton(type: .system)
        dismissButton.setImage(image, for: .normal)
        dismissButton.tintColor = .white
        dismissButton.addTarget(self, action: #selector(dismissTapped), for: .touchUpInside)
        
        if let blurView = dismissCircle as? UIVisualEffectView {
            blurView.contentView.addSubview(dismissButton)
        } else {
            dismissCircle.addSubview(dismissButton)
        }
        
        dismissButton.translatesAutoresizingMaskIntoConstraints = false
        
        NSLayoutConstraint.activate([
            dismissCircle.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor, constant: 16),
            dismissCircle.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 20),
            dismissCircle.widthAnchor.constraint(equalToConstant: 42),
            dismissCircle.heightAnchor.constraint(equalToConstant: 42),
            
            dismissButton.centerXAnchor.constraint(equalTo: dismissCircle.centerXAnchor),
            dismissButton.centerYAnchor.constraint(equalTo: dismissCircle.centerYAnchor),
            dismissButton.widthAnchor.constraint(equalToConstant: 40),
            dismissButton.heightAnchor.constraint(equalToConstant: 40)
        ])
    }
    
    func setupMarqueeLabel() {
        let titleContainer = UIView()
        titleContainer.translatesAutoresizingMaskIntoConstraints = false
        titleContainer.backgroundColor = .clear
        controlsContainerView.addSubview(titleContainer) 
        
        episodeNumberLabel = UILabel()
        episodeNumberLabel.text = "Episode \(episodeNumber)"
        episodeNumberLabel.textColor = UIColor(white: 1.0, alpha: 0.6)
        episodeNumberLabel.font = UIFont.systemFont(ofSize: 14, weight: .semibold)
        episodeNumberLabel.textAlignment = .left
        episodeNumberLabel.setContentHuggingPriority(.required, for: .vertical)
        episodeNumberLabel.translatesAutoresizingMaskIntoConstraints = false
        
        titleLabel = MarqueeLabel(frame: .zero, duration: 8.0, fadeLength: 10.0)
        titleLabel.text = titleText
        titleLabel.type = .continuous
        titleLabel.textColor = .white
        titleLabel.font = UIFont.systemFont(ofSize: 20, weight: .heavy)
        titleLabel.speed = .rate(35)
        titleLabel.fadeLength = 10.0
        titleLabel.leadingBuffer = 1.0
        titleLabel.trailingBuffer = 16.0
        titleLabel.animationDelay = 2.5
        titleLabel.lineBreakMode = .byTruncatingTail
        titleLabel.textAlignment = .left
        titleLabel.setContentHuggingPriority(.defaultLow, for: .vertical)
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        
        titleStackView = UIStackView(arrangedSubviews: [episodeNumberLabel, titleLabel])
        titleStackView.axis = .vertical
        titleStackView.alignment = .leading
        titleStackView.spacing = 0
        titleStackView.clipsToBounds = false
        titleStackView.isLayoutMarginsRelativeArrangement = true
        titleStackView.translatesAutoresizingMaskIntoConstraints = false
        titleContainer.addSubview(titleStackView)
        
        NSLayoutConstraint.activate([
            titleContainer.leadingAnchor.constraint(equalTo: controlsContainerView.leadingAnchor, constant: 18),
            titleContainer.widthAnchor.constraint(lessThanOrEqualTo: controlsContainerView.widthAnchor, multiplier: 0.7),
            titleContainer.heightAnchor.constraint(equalToConstant: 50)
        ])
        

        NSLayoutConstraint.activate([
            titleStackView.leadingAnchor.constraint(equalTo: titleContainer.leadingAnchor),
            titleStackView.trailingAnchor.constraint(equalTo: titleContainer.trailingAnchor),
            titleStackView.topAnchor.constraint(equalTo: titleContainer.topAnchor),
            titleStackView.bottomAnchor.constraint(equalTo: titleContainer.bottomAnchor)
        ])
        
        NSLayoutConstraint.activate([
            episodeNumberLabel.leadingAnchor.constraint(equalTo: titleStackView.leadingAnchor),
            episodeNumberLabel.trailingAnchor.constraint(lessThanOrEqualTo: titleStackView.trailingAnchor),
            titleLabel.leadingAnchor.constraint(equalTo: titleStackView.leadingAnchor),
            titleLabel.trailingAnchor.constraint(lessThanOrEqualTo: titleStackView.trailingAnchor)
        ])
        
        titleStackAboveSkipButtonConstraints = []
        titleStackAboveSliderConstraints = []
    }
    
    func volumeSlider() {
        let container = VolumeSliderContainer(volumeVM: self.volumeViewModel) { newVal in
            if let sysSlider = self.systemVolumeSlider {
                sysSlider.value = Float(newVal)
            }
        }
        
        let hostingController = UIHostingController(rootView: container)
        hostingController.view.backgroundColor = UIColor.clear
        hostingController.view.translatesAutoresizingMaskIntoConstraints = false
        
        let volumeCapsule = GradientBlurButton(type: .custom)
        volumeCapsule.translatesAutoresizingMaskIntoConstraints = false
        volumeCapsule.backgroundColor = .white
        volumeCapsule.layer.cornerRadius = 21
        volumeCapsule.clipsToBounds = true
        controlsContainerView.addSubview(volumeCapsule)
        
        if let blurView = volumeCapsule as? UIVisualEffectView {
            blurView.contentView.addSubview(hostingController.view)
        } else {
            volumeCapsule.addSubview(hostingController.view)
        }
        addChild(hostingController)
        hostingController.didMove(toParent: self)
        
        self.volumeSliderHostingView = hostingController.view
        
        let forcedLandscape = UserDefaults.standard.bool(forKey: "alwaysLandscape")
        let isLandscape = forcedLandscape || UIDevice.current.orientation.isLandscape || view.bounds.width > view.bounds.height
        
        if isLandscape {
            NSLayoutConstraint.activate([
                volumeCapsule.centerYAnchor.constraint(equalTo: dismissButton.centerYAnchor),
                volumeCapsule.trailingAnchor.constraint(equalTo: controlsContainerView.trailingAnchor, constant: -16),
                volumeCapsule.heightAnchor.constraint(equalToConstant: 42),
                volumeCapsule.widthAnchor.constraint(equalToConstant: 200),
                
                hostingController.view.centerYAnchor.constraint(equalTo: volumeCapsule.centerYAnchor),
                hostingController.view.leadingAnchor.constraint(equalTo: volumeCapsule.leadingAnchor, constant: 20),
                hostingController.view.trailingAnchor.constraint(equalTo: volumeCapsule.trailingAnchor, constant: -20),
                hostingController.view.heightAnchor.constraint(equalToConstant: 30)
            ])
        } else {
            NSLayoutConstraint.activate([
                volumeCapsule.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 20),
                volumeCapsule.trailingAnchor.constraint(equalTo: controlsContainerView.trailingAnchor, constant: -16),
                volumeCapsule.heightAnchor.constraint(equalToConstant: 42),
                volumeCapsule.widthAnchor.constraint(equalToConstant: 200),
                
                hostingController.view.centerYAnchor.constraint(equalTo: volumeCapsule.centerYAnchor),
                hostingController.view.leadingAnchor.constraint(equalTo: volumeCapsule.leadingAnchor, constant: 20),
                hostingController.view.trailingAnchor.constraint(equalTo: volumeCapsule.trailingAnchor, constant: -20),
                hostingController.view.heightAnchor.constraint(equalToConstant: 30)
            ])
        }
        
        self.volumeSliderHostingView = volumeCapsule
        
        volumeCapsule.alpha = 1.0
        volumeCapsule.isHidden = false
        hostingController.view.alpha = 1.0
        hostingController.view.isHidden = false
    }
    
    private func setupHoldSpeedIndicator() {
        let config = UIImage.SymbolConfiguration(pointSize: 14, weight: .bold)
        let image = UIImage(systemName: "forward.fill", withConfiguration: config)
        var speed = UserDefaults.standard.float(forKey: "holdSpeedPlayer")
        
        if speed == 0.0 {
            speed = 2.0
        }
        
        holdSpeedIndicator = UIButton(type: .system)
        holdSpeedIndicator.setTitle(" \(speed)", for: .normal)
        holdSpeedIndicator.titleLabel?.font = UIFont.systemFont(ofSize: 14, weight: .bold)
        holdSpeedIndicator.setImage(image, for: .normal)
        holdSpeedIndicator.contentEdgeInsets = UIEdgeInsets(top: 6, left: 10, bottom: 6, right: 10)
        holdSpeedIndicator.tintColor = .white
        holdSpeedIndicator.setTitleColor(.white, for: .normal)
        holdSpeedIndicator.alpha = 0.0
        
        let blurEffect = UIBlurEffect(style: .systemUltraThinMaterial)
        let blurView = UIVisualEffectView(effect: blurEffect)
        blurView.translatesAutoresizingMaskIntoConstraints = false
        blurView.layer.cornerRadius = 21
        blurView.clipsToBounds = true
        
        view.addSubview(holdSpeedIndicator)
        holdSpeedIndicator.translatesAutoresizingMaskIntoConstraints = false
        
        holdSpeedIndicator.insertSubview(blurView, at: 0)
        
        NSLayoutConstraint.activate([
            holdSpeedIndicator.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            holdSpeedIndicator.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 20),
            holdSpeedIndicator.heightAnchor.constraint(equalToConstant: 40),
            holdSpeedIndicator.widthAnchor.constraint(greaterThanOrEqualToConstant: 85),
            
            blurView.leadingAnchor.constraint(equalTo: holdSpeedIndicator.leadingAnchor),
            blurView.trailingAnchor.constraint(equalTo: holdSpeedIndicator.trailingAnchor),
            blurView.topAnchor.constraint(equalTo: holdSpeedIndicator.topAnchor),
            blurView.bottomAnchor.constraint(equalTo: holdSpeedIndicator.bottomAnchor)
        ])
        
        holdSpeedIndicator.isUserInteractionEnabled = false
        holdSpeedIndicator.layer.cornerRadius = 21
        holdSpeedIndicator.clipsToBounds = true
        
        holdSpeedIndicator.bringSubviewToFront(holdSpeedIndicator.imageView!)
        holdSpeedIndicator.bringSubviewToFront(holdSpeedIndicator.titleLabel!)
        
        holdSpeedIndicator.imageView?.contentMode = .scaleAspectFit
        holdSpeedIndicator.titleLabel?.textAlignment = .center
    }
    
    func updateMarqueeConstraintsForBottom() {
        NSLayoutConstraint.deactivate(titleStackAboveSkipButtonConstraints)
        NSLayoutConstraint.deactivate(titleStackAboveSliderConstraints)
        
        let forcedLandscape = UserDefaults.standard.bool(forKey: "alwaysLandscape")
        let isLandscape = forcedLandscape || view.bounds.width > view.bounds.height
        titleStackView.isHidden = !isLandscape
        titleStackView.alpha = isLandscape ? 1.0 : 0.0
        episodeNumberLabel.isHidden = !isLandscape
        titleLabel.isHidden = !isLandscape
        episodeNumberLabel.alpha = isLandscape ? 1.0 : 0.0
        titleLabel.alpha = isLandscape ? 1.0 : 0.0
        
        if !isLandscape {
            return
        }
        
        titleLabel.textAlignment = .left
        episodeNumberLabel.textAlignment = .left
        
        let skipIntroVisible = !(skipIntroButton?.isHidden ?? true) && (skipIntroButton?.alpha ?? 0) > 0.1
        let skip85Visible = !(skip85Button?.isHidden ?? true) && (skip85Button?.alpha ?? 0) > 0.1
        
        if skipIntroVisible && skipIntroButton?.superview != nil {
            titleStackAboveSkipButtonConstraints = [
                titleStackView.superview!.bottomAnchor.constraint(equalTo: skipIntroButton.topAnchor, constant: -4)
            ]
            NSLayoutConstraint.activate(titleStackAboveSkipButtonConstraints)
        } else if skip85Visible && skip85Button?.superview != nil {
            titleStackAboveSkipButtonConstraints = [
                titleStackView.superview!.bottomAnchor.constraint(equalTo: skip85Button.topAnchor, constant: -4)
            ]
            NSLayoutConstraint.activate(titleStackAboveSkipButtonConstraints)
        } else if let sliderView = sliderHostingController?.view {
            titleStackAboveSliderConstraints = [
                titleStackView.superview!.bottomAnchor.constraint(equalTo: sliderView.topAnchor, constant: -4)
            ]
            NSLayoutConstraint.activate(titleStackAboveSliderConstraints)
        }
        
        if isLandscape {
            titleLabel.restartLabel()
        }
        
        view.layoutIfNeeded()
    }
    
    func updateSkipButtonsVisibility() {
        if !isControlsVisible { return }
        let t = currentTimeVal
        
        let skipIntroAvailable = skipIntervals.op != nil &&
        t >= skipIntervals.op!.start.seconds &&
        t <= skipIntervals.op!.end.seconds &&
        !skipIntroDismissedInSession
        
        let skipOutroAvailable = skipIntervals.ed != nil &&
        t >= skipIntervals.ed!.start.seconds &&
        t <= skipIntervals.ed!.end.seconds &&
        !skipOutroDismissedInSession
        
        let shouldShowSkip85 = isSkip85Visible && !skipIntroAvailable
        
        if skipIntroAvailable {
            skipIntroButton.setTitle(" Skip Intro", for: .normal)
            skipIntroButton.setImage(UIImage(systemName: "forward.frame"), for: .normal)
            UIView.animate(withDuration: 0.2) {
                self.skipIntroButton.alpha = 1.0
            }
        } else {
            UIView.animate(withDuration: 0.2) {
                self.skipIntroButton.alpha = 0.0
            }
        }
        
        if shouldShowSkip85 && (skip85Button.isHidden || skip85Button.alpha < 0.1) {
            skip85Button.setTitle(" Skip 85s", for: .normal)
            skip85Button.setImage(UIImage(systemName: "goforward"), for: .normal)
            skip85Button.isHidden = false
            UIView.animate(withDuration: 0.2) {
                self.skip85Button.alpha = 1.0
            }
        } else if !shouldShowSkip85 && (!skip85Button.isHidden || skip85Button.alpha > 0) {
            UIView.animate(withDuration: 0.2) {
                self.skip85Button.alpha = 0.0
            } completion: { _ in
                if !shouldShowSkip85 {
                    self.skip85Button.isHidden = true
                }
            }
        }
        
        view.bringSubviewToFront(skip85Button)
        
        if skipOutroAvailable {
            if skipOutroButton.superview == nil {
                controlsContainerView.addSubview(skipOutroButton)
                
                NSLayoutConstraint.activate([
                    skipOutroButton.trailingAnchor.constraint(equalTo: sliderHostingController!.view.trailingAnchor),
                    skipOutroButton.bottomAnchor.constraint(equalTo: sliderHostingController!.view.topAnchor, constant: -5),
                    skipOutroButton.heightAnchor.constraint(equalToConstant: 40),
                    skipOutroButton.widthAnchor.constraint(greaterThanOrEqualToConstant: 104)
                ])
                
                view.setNeedsLayout()
                view.layoutIfNeeded()
            }
            
            UIView.animate(withDuration: 0.2) {
                self.skipOutroButton.alpha = 1.0
            }
        } else {
            removeSkipOutroButton()
        }
        
        if !isMenuOpen {
            updateControlButtonsContainerPosition()
            updateMarqueeConstraintsForBottom()
            
            UIView.animate(withDuration: 0.25) {
                self.view.layoutIfNeeded()
            }
        }
        
        let hasVisibleButtons = [watchNextButton, speedButton, qualityButton, menuButton].contains { button in
            guard let button = button else { return false }
            return !button.isHidden
        }
        
        if !isMenuOpen && (hasVisibleButtons || controlButtonsContainer.superview != nil) {
            self.setupControlButtonsContainer()
        }
    }
    
    private func updateControlButtonsContainerPosition() {
        guard controlButtonsContainer.superview != nil else { return }
        
        controlButtonsContainerBottomConstraint?.isActive = false
        
        let skipOutroActuallyVisible = skipOutroButton.superview != nil && skipOutroButton.alpha > 0.1
        
        if !skipOutroActuallyVisible {
            controlButtonsContainerBottomConstraint = controlButtonsContainer.bottomAnchor.constraint(
                equalTo: sliderHostingController!.view.topAnchor, constant: -27)
        } else {
            controlButtonsContainerBottomConstraint = controlButtonsContainer.bottomAnchor.constraint(
                equalTo: skipOutroButton.topAnchor, constant: -5)
        }
        
        controlButtonsContainerBottomConstraint?.isActive = true
    }
    
    private func updateSegments() {
        sliderViewModel.introSegments.removeAll()
        sliderViewModel.outroSegments.removeAll()
        
        if let op = skipIntervals.op {
            let start = max(0, op.start.seconds / max(duration, 0.01))
            let end = min(1, op.end.seconds / max(duration, 0.01))
            
            if start <= end {
                sliderViewModel.introSegments.append(start...end)
            }
        }
        
        if let ed = skipIntervals.ed {
            let start = max(0, ed.start.seconds / max(duration, 0.01))
            let end = min(1, ed.end.seconds / max(duration, 0.01))
            
            if start <= end {
                sliderViewModel.outroSegments.append(start...end)
            }
        }
        
        let segmentsColor = self.getSegmentsColor()
        
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            let validDuration = max(self.duration, 0.01)
            
            self.sliderHostingController?.rootView = MusicProgressSlider(
                value: Binding(
                    get: { max(0, min(self.sliderViewModel.sliderValue, validDuration)) },
                    set: { self.sliderViewModel.sliderValue = max(0, min($0, validDuration)) }
                ),
                inRange: 0...validDuration,
                activeFillColor: .white,
                fillColor: .white,
                textColor: .white.opacity(0.7),
                emptyColor: .white.opacity(0.3),
                height: 33,
                onEditingChanged: { editing in
                    if editing {
                        self.isSliderEditing = true
                        self.wasPlayingBeforeSeek = (self.player.timeControlStatus == .playing)
                        self.originalRate = self.player.rate
                        self.player.pause()
                    } else {
                        let target = CMTime(seconds: self.sliderViewModel.sliderValue, preferredTimescale: 600)
                        self.player.seek(to: target, toleranceBefore: .zero, toleranceAfter: .zero) { [weak self] _ in
                            guard let self = self else { return }
                            let final = self.player.currentTime().seconds
                            self.sliderViewModel.sliderValue = final
                            self.currentTimeVal = final
                            self.isSliderEditing = false
                            
                            if self.wasPlayingBeforeSeek {
                                self.player.playImmediately(atRate: self.originalRate)
                            }
                        }
                    }
                },
                introSegments: self.sliderViewModel.introSegments,
                outroSegments: self.sliderViewModel.outroSegments,
                introColor: segmentsColor,
                outroColor: segmentsColor
            )
        }
    }
    
    private func fetchSkipTimes(type: String) {
        guard let mal = malID else { return }
        let url = URL(string: "https://api.aniskip.com/v2/skip-times/\(mal)/\(episodeNumber)?types=\(type)&episodeLength=0")!
        URLSession.shared.dataTask(with: url) { data, _, _ in
            guard let d = data,
                  let resp = try? JSONDecoder().decode(AniSkipResponse.self, from: d),
                  resp.found,
                  let interval = resp.results.first?.interval else { return }
            
            let range = CMTimeRange(
                start: CMTime(seconds: interval.startTime, preferredTimescale: 600),
                end: CMTime(seconds: interval.endTime, preferredTimescale: 600)
            )
            DispatchQueue.main.async {
                if type == "op" {
                    self.skipIntervals.op = range
                } else {
                    self.skipIntervals.ed = range
                }
                if self.duration > 0 {
                    self.updateSegments()
                }
            }
        }.resume()
    }
    
    func setupSkipButtons() {
        let introConfig = UIImage.SymbolConfiguration(pointSize: 14, weight: .bold)
        let introImage = UIImage(systemName: "forward.frame", withConfiguration: introConfig)
        skipIntroButton = GradientBlurButton(type: .system)
        skipIntroButton.setTitle(" Skip Intro", for: .normal)
        skipIntroButton.titleLabel?.font = UIFont.systemFont(ofSize: 14, weight: .bold)
        skipIntroButton.setImage(introImage, for: .normal)
        skipIntroButton.contentEdgeInsets = UIEdgeInsets(top: 6, left: 10, bottom: 6, right: 10)
        skipIntroButton.tintColor = .white
        skipIntroButton.setTitleColor(.white, for: .normal)
        skipIntroButton.layer.cornerRadius = 21
        skipIntroButton.clipsToBounds = false
        skipIntroButton.alpha = 0.0
        skipIntroButton.addTarget(self, action: #selector(skipIntro), for: .touchUpInside)
        controlsContainerView.addSubview(skipIntroButton)
        skipIntroButton.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            skipIntroButton.leadingAnchor.constraint(equalTo: controlsContainerView.leadingAnchor, constant: 18),
            skipIntroButton.bottomAnchor.constraint(equalTo: sliderHostingController!.view.topAnchor, constant: -12),
            skipIntroButton.heightAnchor.constraint(equalToConstant: 40),
            skipIntroButton.widthAnchor.constraint(greaterThanOrEqualToConstant: 104)
        ])
        
        let outroConfig = UIImage.SymbolConfiguration(pointSize: 14, weight: .bold)
        let outroImage = UIImage(systemName: "forward.frame", withConfiguration: outroConfig)
        skipOutroButton = GradientBlurButton(type: .system)
        skipOutroButton.setTitle(" Skip Outro", for: .normal)
        skipOutroButton.titleLabel?.font = UIFont.systemFont(ofSize: 14, weight: .bold)
        skipOutroButton.setImage(outroImage, for: .normal)
        skipOutroButton.contentEdgeInsets = UIEdgeInsets(top: 6, left: 10, bottom: 6, right: 10)
        skipOutroButton.tintColor = .white
        skipOutroButton.setTitleColor(.white, for: .normal)
        skipOutroButton.layer.cornerRadius = 21
        skipOutroButton.clipsToBounds = false
        skipOutroButton.alpha = 0.0
        skipOutroButton.addTarget(self, action: #selector(skipOutro), for: .touchUpInside)
        skipOutroButton.translatesAutoresizingMaskIntoConstraints = false
    }
    
    func setupSkip85Button() {
        let config = UIImage.SymbolConfiguration(pointSize: 14, weight: .bold)
        let image = UIImage(systemName: "goforward", withConfiguration: config)?.withRenderingMode(.alwaysTemplate)
        skip85Button = GradientBlurButton(type: .system)
        skip85Button.setTitle(" Skip 85s", for: .normal)
        skip85Button.titleLabel?.font = UIFont.systemFont(ofSize: 14, weight: .bold)
        skip85Button.setImage(image, for: .normal)
        skip85Button.imageView?.contentMode = .scaleAspectFit
        skip85Button.contentEdgeInsets = UIEdgeInsets(top: 6, left: 10, bottom: 6, right: 10)
        skip85Button.tintColor = .white
        skip85Button.setTitleColor(.white, for: .normal)
        skip85Button.layer.cornerRadius = 21
        skip85Button.clipsToBounds = false
        skip85Button.alpha = 0.0
        skip85Button.isHidden = !isSkip85Visible 
        skip85Button.addTarget(self, action: #selector(skip85Tapped), for: .touchUpInside)
        controlsContainerView.addSubview(skip85Button)
        skip85Button.translatesAutoresizingMaskIntoConstraints = false
        
        let skip85Constraints = [
            skip85Button.leadingAnchor.constraint(equalTo: controlsContainerView.leadingAnchor, constant: 18),
            skip85Button.bottomAnchor.constraint(equalTo: sliderHostingController!.view.topAnchor, constant: -12),
            skip85Button.heightAnchor.constraint(equalToConstant: 40),
            skip85Button.widthAnchor.constraint(greaterThanOrEqualToConstant: 104)
        ]
        NSLayoutConstraint.activate(skip85Constraints)
    }
    
    private func setupQualityButton() {
        let image = UIImage(systemName: "tv", withConfiguration: bottomControlsCfg)
        
        qualityButton = UIButton(type: .system)
        qualityButton.setImage(image, for: .normal)
        qualityButton.tintColor = .white
        qualityButton.showsMenuAsPrimaryAction = true
        qualityButton.menu = qualitySelectionMenu()
        qualityButton.isHidden = true
        
        qualityButton.addTarget(self, action: #selector(protectMenuFromRecreation), for: .touchDown)
        
        qualityButton.translatesAutoresizingMaskIntoConstraints = false
    }
    
    private func setupControlButtonsContainer() {
        controlButtonsContainer?.removeFromSuperview()
        
        controlButtonsContainer = GradientBlurButton(type: .custom)
        controlButtonsContainer.isUserInteractionEnabled = true
        controlButtonsContainer.translatesAutoresizingMaskIntoConstraints = false
        controlButtonsContainer.backgroundColor = .clear
        controlButtonsContainer.layer.cornerRadius = 21
        controlButtonsContainer.clipsToBounds = true
        controlsContainerView.addSubview(controlButtonsContainer)
        
        Logger.shared.log("Setting up control buttons container - isHLSStream: \(isHLSStream)", type: "Debug")
        
        if isHLSStream {
            Logger.shared.log("HLS stream detected, showing quality button", type: "Debug")
            qualityButton.isHidden = false
            qualityButton.menu = qualitySelectionMenu()
        } else {
            Logger.shared.log("Not an HLS stream, quality button will be hidden", type: "Debug")
            qualityButton.isHidden = true
        }
        
        let visibleButtons = [watchNextButton, speedButton, qualityButton, menuButton].compactMap { button -> UIButton? in
            guard let button = button else {
                Logger.shared.log("Button is nil", type: "Debug")
                return nil
            }
            
            if button == qualityButton {
                Logger.shared.log("Quality button state - isHidden: \(button.isHidden), isHLSStream: \(isHLSStream)", type: "Debug")
            }
            
            if button.isHidden {
                if button == qualityButton {
                    Logger.shared.log("Quality button is hidden, skipping", type: "Debug")
                }
                return nil
            }
            
            controlButtonsContainer.addSubview(button)
            button.layer.shadowOpacity = 0
            
            if button == qualityButton {
                Logger.shared.log("Quality button added to container", type: "Debug")
            }
            
            return button
        }
        
        Logger.shared.log("Visible buttons count: \(visibleButtons.count)", type: "Debug")
        Logger.shared.log("Visible buttons: \(visibleButtons.map { $0 == watchNextButton ? "watchNext" : $0 == speedButton ? "speed" : $0 == qualityButton ? "quality" : "menu" })", type: "Debug")
        
        if visibleButtons.isEmpty {
            Logger.shared.log("No visible buttons, removing container from view hierarchy", type: "Debug")
            controlButtonsContainer.removeFromSuperview()
            return
        }
        
        controlButtonsContainer.alpha = 1.0
        
        for (index, button) in visibleButtons.enumerated() {
            NSLayoutConstraint.activate([
                button.centerYAnchor.constraint(equalTo: controlButtonsContainer.centerYAnchor),
                button.heightAnchor.constraint(equalToConstant: 40),
                button.widthAnchor.constraint(equalToConstant: 40)
            ])
            
            if index == 0 {
                button.trailingAnchor.constraint(equalTo: controlButtonsContainer.trailingAnchor, constant: -10).isActive = true
            } else {
                button.trailingAnchor.constraint(equalTo: visibleButtons[index - 1].leadingAnchor, constant: -6).isActive = true
            }
            
            if index == visibleButtons.count - 1 {
                controlButtonsContainer.leadingAnchor.constraint(equalTo: button.leadingAnchor, constant: -10).isActive = true
            }
        }
        
        NSLayoutConstraint.activate([
            controlButtonsContainer.trailingAnchor.constraint(equalTo: sliderHostingController!.view.trailingAnchor),
            controlButtonsContainer.heightAnchor.constraint(equalToConstant: 42)
        ])
        
        let skipOutroActuallyVisible = skipOutroButton.superview != nil && skipOutroButton.alpha > 0.1
        
        if skipOutroActuallyVisible {
            controlButtonsContainerBottomConstraint = controlButtonsContainer.bottomAnchor.constraint(
                equalTo: skipOutroButton.topAnchor, constant: -5)
        } else {
            controlButtonsContainerBottomConstraint = controlButtonsContainer.bottomAnchor.constraint(
                equalTo: sliderHostingController!.view.topAnchor, constant: -12)
        }
        
        controlButtonsContainerBottomConstraint?.isActive = true
        
        Logger.shared.log("Control buttons container setup complete", type: "Debug")
    }
    
    func updateSubtitleLabelAppearance() {
        for subtitleLabel in subtitleLabels {
            subtitleLabel.font = UIFont.systemFont(ofSize: CGFloat(subtitleFontSize))
            subtitleLabel.textColor = subtitleUIColor()
            subtitleLabel.backgroundColor = subtitleBackgroundEnabled
            ? UIColor.black.withAlphaComponent(0.6)
            : .clear
            subtitleLabel.layer.cornerRadius = 5
            subtitleLabel.clipsToBounds = true
            subtitleLabel.layer.shadowColor = UIColor.black.cgColor
            subtitleLabel.layer.shadowRadius = CGFloat(subtitleShadowRadius)
            subtitleLabel.layer.shadowOpacity = 1.0
            subtitleLabel.layer.shadowOffset = .zero
        }
    }
    
    func addTimeObserver() {
        let interval = CMTime(seconds: 1.0, preferredTimescale: CMTimeScale(NSEC_PER_SEC))
        timeObserverToken = player.addPeriodicTimeObserver(forInterval: interval, queue: .main) { [weak self] time in
            guard let self = self,
                  let currentItem = self.player.currentItem,
                  currentItem.duration.seconds.isFinite else { return }
            
            let currentDuration = currentItem.duration.seconds
            if currentDuration.isNaN || currentDuration <= 0 { return }
            
            self.currentTimeVal = time.seconds
            self.duration = currentDuration
            self.updateSegments()
            
            if !self.isSliderEditing {
                self.sliderViewModel.sliderValue = max(0, min(self.currentTimeVal, self.duration))
            }
            
            self.updateEndTime()
            
            self.updateSkipButtonsVisibility()
            
            UserDefaults.standard.set(self.currentTimeVal, forKey: "lastPlayedTime_\(self.fullUrl)")
            UserDefaults.standard.set(self.duration, forKey: "totalTime_\(self.fullUrl)")
            
            if self.subtitlesEnabled {
                let adjustedTime = self.currentTimeVal - self.subtitleDelay
                let cues = self.subtitlesLoader.cues.filter { adjustedTime >= $0.startTime && adjustedTime <= $0.endTime }
                if cues.count > 0 {
                    self.subtitleLabels[0].text = cues[0].text.strippedHTML
                    self.subtitleLabels[0].isHidden = false
                } else {
                    self.subtitleLabels[0].text = ""
                    self.subtitleLabels[0].isHidden = !self.subtitlesEnabled
                }
                if cues.count > 1 {
                    self.subtitleLabels[1].text = cues[1].text.strippedHTML
                    self.subtitleLabels[1].isHidden = false
                } else {
                    self.subtitleLabels[1].text = ""
                    self.subtitleLabels[1].isHidden = true
                }
            } else {
                self.subtitleLabels[0].text = ""
                self.subtitleLabels[0].isHidden = true
                self.subtitleLabels[1].text = ""
                self.subtitleLabels[1].isHidden = true
            }
            
            let segmentsColor = self.getSegmentsColor()
            
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                if let currentItem = self.player.currentItem, currentItem.duration.seconds > 0 {
                    let progress = min(max(self.currentTimeVal / self.duration, 0), 1.0)
                    
                    let item = ContinueWatchingItem(
                        id: UUID(),
                        imageUrl: self.episodeImageUrl,
                        episodeNumber: self.episodeNumber,
                        mediaTitle: self.titleText,
                        progress: progress,
                        streamUrl: self.streamURL,
                        fullUrl: self.fullUrl,
                        subtitles: self.subtitlesURL,
                        aniListID: self.aniListID,
                        module: self.module,
                        headers: self.headers,
                        totalEpisodes: self.totalEpisodes
                    )
                    ContinueWatchingManager.shared.save(item: item)
                }
                
                let remainingPercentage = (self.duration - self.currentTimeVal) / self.duration
                let remainingTimePercentage = UserDefaults.standard.object(forKey: "remainingTimePercentage") != nil ? UserDefaults.standard.double(forKey: "remainingTimePercentage") : 90.0
                let threshold = (100.0 - remainingTimePercentage) / 100.0
                
                if remainingPercentage <= threshold {
                    if self.aniListID != 0 && !self.aniListUpdatedSuccessfully && !self.aniListUpdateImpossible {
                        self.tryAniListUpdate()
                    }
                    
                    if let tmdbId = self.tmdbID, tmdbId > 0, !self.traktUpdateSent {
                        self.sendTraktUpdate(tmdbId: tmdbId)
                    }
                }
                
                self.sliderHostingController?.rootView = MusicProgressSlider(
                    value: Binding(
                        get: { max(0, min(self.sliderViewModel.sliderValue, self.duration)) },
                        set: {
                            self.sliderViewModel.sliderValue = max(0, min($0, self.duration))
                        }
                    ),
                    inRange: 0...(self.duration > 0 ? self.duration : 1.0),
                    activeFillColor: .white,
                    fillColor: .white,
                    textColor: .white.opacity(0.7),
                    emptyColor: .white.opacity(0.3),
                    height: 33,
                    onEditingChanged: { editing in
                        if editing {
                            self.isSliderEditing = true
                            
                            self.wasPlayingBeforeSeek = (self.player.timeControlStatus == .playing)
                            self.originalRate = self.player.rate
                            
                            self.player.pause()
                        } else {
                            let target = CMTime(seconds: self.sliderViewModel.sliderValue,
                                                preferredTimescale: 600)
                            self.player.seek(
                                to: target,
                                toleranceBefore: .zero,
                                toleranceAfter: .zero
                            ) { [weak self] _ in
                                guard let self = self else { return }
                                
                                let final = self.player.currentTime().seconds
                                self.sliderViewModel.sliderValue = final
                                self.currentTimeVal = final
                                self.isSliderEditing = false
                                
                                if self.wasPlayingBeforeSeek {
                                    self.player.playImmediately(atRate: self.originalRate)
                                }
                            }
                        }
                    },
                    introSegments: self.sliderViewModel.introSegments,
                    outroSegments: self.sliderViewModel.outroSegments,
                    introColor: segmentsColor,
                    outroColor: segmentsColor
                )
            }
        }
    }
    
    func startUpdateTimer() {
        updateTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            self.currentTimeVal = self.player.currentTime().seconds
        }
    }
    
    @objc func toggleControls() {
        if controlsLocked {
            unlockButton.alpha = 1.0
            lockButtonTimer?.invalidate()
            lockButtonTimer = Timer.scheduledTimer(
                withTimeInterval: 3.0,
                repeats: false
            ) { [weak self] _ in
                UIView.animate(withDuration: 0.3) {
                    self?.unlockButton.alpha = 0
                }
            }
            return
        }
        
        isControlsVisible.toggle()
        
        if isDimmed {
            dimButton.isHidden = false
            dimButton.alpha = 1.0
            dimButtonTimer?.invalidate()
            dimButtonTimer = Timer.scheduledTimer(withTimeInterval: 3.0, repeats: false) { [weak self] _ in
                UIView.animate(withDuration: 0.3) {
                    self?.dimButton.alpha = 0
                }
            }
        }
        
        let holdSpeedAlpha = holdSpeedIndicator?.alpha ?? 0
        
        UIView.animate(withDuration: 0.2) {
            let alpha: CGFloat = self.isControlsVisible ? 1.0 : 0.0
            
            for control in self.controlsToHide {
                control.alpha = alpha
            }
            
            self.dismissButton.alpha = self.isControlsVisible ? 1.0 : 0.0
            
            if let holdSpeed = self.holdSpeedIndicator {
                holdSpeed.alpha = holdSpeedAlpha
            }
            
            if self.isControlsVisible {
                if self.isSkip85Visible {
                    self.skip85Button.isHidden = false
                }
                self.skipIntroButton.alpha = 0.0
                self.skipOutroButton.alpha = 0.0
            }
            
            self.subtitleBottomToSafeAreaConstraint?.isActive = !self.isControlsVisible
            self.subtitleBottomToSliderConstraint?.isActive = self.isControlsVisible
            self.view.layoutIfNeeded()
        }
        
        if isControlsVisible {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                self.setupControlButtonsContainer()
                self.updateSkipButtonsVisibility()
            }
        } else {
            updateSkipButtonsVisibility()
        }
    }
    
    @objc func seekBackwardLongPress(_ gesture: UILongPressGestureRecognizer) {
        if gesture.state == .began {
            let holdValue = UserDefaults.standard.double(forKey: "skipIncrementHold")
            let finalSkip = holdValue > 0 ? holdValue : 30
            currentTimeVal = max(currentTimeVal - finalSkip, 0)
            player.seek(to: CMTime(seconds: currentTimeVal, preferredTimescale: 600)) { [weak self] finished in
                guard self != nil else { return }
            }
            animateButtonRotation(backwardButton, clockwise: false)
        }
    }
    
    @objc func seekForwardLongPress(_ gesture: UILongPressGestureRecognizer) {
        if gesture.state == .began {
            let holdValue = UserDefaults.standard.double(forKey: "skipIncrementHold")
            let finalSkip = holdValue > 0 ? holdValue : 30
            currentTimeVal = min(currentTimeVal + finalSkip, duration)
            player.seek(to: CMTime(seconds: currentTimeVal, preferredTimescale: 600)) { [weak self] finished in
                guard self != nil else { return }
            }
            animateButtonRotation(forwardButton)
        }
    }
    
    @objc func seekBackward() {
        let skipValue = UserDefaults.standard.double(forKey: "skipIncrement")
        let finalSkip = skipValue > 0 ? skipValue : 10
        
        currentTimeVal = max(currentTimeVal - finalSkip, 0)
        player.seek(to: CMTime(seconds: currentTimeVal, preferredTimescale: 600)) { [weak self] finished in
            guard self != nil else { return }
        }
        animateButtonRotation(backwardButton, clockwise: false)
    }
    
    @objc func seekForward() {
        let skipValue = UserDefaults.standard.double(forKey: "skipIncrement")
        
        let finalSkip = skipValue > 0 ? skipValue : 10
        currentTimeVal = min(currentTimeVal + finalSkip, duration)
        player.seek(to: CMTime(seconds: currentTimeVal, preferredTimescale: 600)) { [weak self] finished in
            guard self != nil else { return }
        }
        animateButtonRotation(forwardButton)
    }
    
    @objc func handleDoubleTap(_ gesture: UITapGestureRecognizer) {
        let tapLocation = gesture.location(in: view)
        if tapLocation.x < view.bounds.width / 2 {
            seekBackward()
            showSkipFeedback(direction: "backward")
        } else {
            seekForward()
            showSkipFeedback(direction: "forward")
        }
        
        skipOutroDismissedInSession = false
    }
    
    @objc func handleSwipeDown(_ gesture: UISwipeGestureRecognizer) {
        dismiss(animated: true, completion: nil)
    }
    
    @objc func togglePlayPause() {
        if isPlaying {
            currentPlaybackSpeed = player.rate
            player.pause()
            isPlaying = false
            playPauseButton.image = UIImage(systemName: "play.fill")
        } else {
            player.play()
            player.rate = currentPlaybackSpeed
            isPlaying = true
            playPauseButton.image = UIImage(systemName: "pause.fill")
        }
    }
    
    @objc private func pipButtonTapped(_ sender: UIButton) {
        Logger.shared.log("PiP button tapped", type: "Debug")
        guard let pip = pipController else {
            Logger.shared.log("PiP controller is nil", type: "Error")
            return
        }
        Logger.shared.log("PiP controller found, isActive: \(pip.isPictureInPictureActive)", type: "Debug")
        if pip.isPictureInPictureActive {
            pip.stopPictureInPicture()
            Logger.shared.log("Stopping PiP", type: "Debug")
        } else {
            pip.startPictureInPicture()
            Logger.shared.log("Starting PiP", type: "Debug")
        }
    }
    
    @objc private func startPipIfNeeded() {
        guard isPipAutoEnabled,
              let pip = pipController,
              !pip.isPictureInPictureActive else {
            return
        }
        pip.startPictureInPicture()
    }
    
    @objc private func lockTapped() {
        controlsLocked.toggle()
        
        isControlsVisible = !controlsLocked
        lockButtonTimer?.invalidate()
        
        let holdSpeedAlpha = holdSpeedIndicator?.alpha ?? 0
        
        if controlsLocked {
            UIView.animate(withDuration: 0.25) {
                self.controlsContainerView.alpha = 0
                self.dimButton.alpha = 0
                for v in self.controlsToHide { v.alpha = 0 }
                self.skipIntroButton.alpha = 0
                self.skipOutroButton.alpha = 0
                self.skip85Button.alpha = 0
                self.lockButton.alpha = 0
                self.unlockButton.alpha = 1
                
                if let holdSpeed = self.holdSpeedIndicator {
                    holdSpeed.alpha = holdSpeedAlpha
                }
                
                self.subtitleBottomToSafeAreaConstraint?.isActive = true
                self.subtitleBottomToSliderConstraint?.isActive = false
                
                self.view.layoutIfNeeded()
            }
            
            lockButton.setImage(UIImage(systemName: "lock"), for: .normal)
            
            lockButtonTimer = Timer.scheduledTimer(
                withTimeInterval: 3.0,
                repeats: false
            ) { [weak self] _ in
                UIView.animate(withDuration: 0.3) {
                    self?.unlockButton.alpha = 0
                }
            }
        } else {
            UIView.animate(withDuration: 0.25) {
                self.controlsContainerView.alpha = 1
                self.dimButton.alpha = 1
                for v in self.controlsToHide { v.alpha = 1 }
                self.unlockButton.alpha = 0
                
                if let holdSpeed = self.holdSpeedIndicator {
                    holdSpeed.alpha = holdSpeedAlpha
                }
                
                self.subtitleBottomToSafeAreaConstraint?.isActive = false
                self.subtitleBottomToSliderConstraint?.isActive = true
                
                self.view.layoutIfNeeded()
            }
            
            lockButton.setImage(UIImage(systemName: "lock.open"), for: .normal)
            updateSkipButtonsVisibility()
        }
    }
    
    @objc private func skipIntro() {
        if let range = skipIntervals.op {
            player.seek(to: range.end)
            skipIntroDismissedInSession = true
            hideSkipIntroButton()
        }
    }
    
    private func hideSkipIntroButton() {
        UIView.animate(withDuration: 0.2) {
            self.skipIntroButton.alpha = 0.0
        } completion: { _ in
            self.updateSkipButtonsVisibility()
            self.view.setNeedsLayout()
            self.view.layoutIfNeeded()
        }
    }
    
    @objc private func skipOutro() {
        if let range = skipIntervals.ed {
            player.seek(to: range.end)
            skipOutroDismissedInSession = true
            removeSkipOutroButton()
        }
    }
    
    private func removeSkipOutroButton() {
        if skipOutroButton.superview != nil {
            UIView.animate(withDuration: 0.2, animations: {
                self.skipOutroButton.alpha = 0.0
            }, completion: { _ in
                self.view.setNeedsLayout()
                self.view.layoutIfNeeded()
                
                self.updateControlButtonsContainerPosition()
                
                let hasVisibleButtons = [self.watchNextButton, self.speedButton, self.qualityButton, self.menuButton].contains { button in
                    guard let button = button else { return false }
                    return !button.isHidden
                }
                if hasVisibleButtons || self.controlButtonsContainer.superview != nil {
                    self.setupControlButtonsContainer()
                }
            })
        }
    }
    
    @objc func dismissTapped() {
        dismiss(animated: true, completion: nil)
    }
    
    @objc func watchNextTapped() {
        player.pause()
        dismiss(animated: true) { [weak self] in
            self?.onWatchNext()
        }
    }
    
    @objc func skip85Tapped() {
        currentTimeVal = min(currentTimeVal + 85, duration)
        player.seek(to: CMTime(seconds: currentTimeVal, preferredTimescale: 600))
    }
    
    @objc private func dimTapped() {
        isDimmed.toggle()
        dimButtonTimer?.invalidate()
        UIView.animate(withDuration: 0.25) {
            self.blackCoverView.alpha = self.isDimmed ? 1.0 : 0.0
            let iconName = self.isDimmed ? "moon.fill" : "moon"
            self.dimButton.setImage(UIImage(systemName: iconName, withConfiguration: self.cfg), for: .normal)
        }
    }
    
    func speedChangerMenu() -> UIMenu {
        let speeds: [Double] = [0.25, 0.5, 0.75, 1.0, 1.25, 1.5, 1.75, 2.0]
        let playbackSpeedActions = speeds.map { speed in
            UIAction(title: String(format: "%.2f", speed)) { _ in
                self.player.rate = Float(speed)
                if self.player.timeControlStatus != .playing {
                    self.player.pause()
                }
            }
        }
        return UIMenu(title: "Playback Speed", children: playbackSpeedActions)
    }
    
    private func tryAniListUpdate() {
        guard !aniListUpdatedSuccessfully else { return }
        
        guard aniListID > 0 else {
            Logger.shared.log("AniList ID is invalid, skipping update.", type: "Warning")
            return
        }
        
        let client = AniListMutation()
        
        client.fetchMediaStatus(mediaId: aniListID) { [weak self] statusResult in
            guard let self = self else { return }
            
            let newStatus: String = {
                switch statusResult {
                case .success(let mediaStatus):
                    if mediaStatus == "RELEASING" {
                        return "CURRENT"
                    }
                    return (self.episodeNumber == self.totalEpisodes) ? "COMPLETED" : "CURRENT"
                    
                case .failure(let error):
                    Logger.shared.log(
                        "Failed to fetch AniList status: \(error.localizedDescription). " +
                        "Using default CURRENT/COMPLETED logic.",
                        type: "Warning"
                    )
                    return (self.episodeNumber == self.totalEpisodes) ? "COMPLETED" : "CURRENT"
                }
            }()
            
            client.updateAnimeProgress(
                animeId: self.aniListID,
                episodeNumber: self.episodeNumber,
                status: newStatus
            ) { result in
                switch result {
                case .success:
                    self.aniListUpdatedSuccessfully = true
                    Logger.shared.log(
                        "AniList progress updated to \(newStatus) for ep \(self.episodeNumber)",
                        type: "General"
                    )
                    
                case .failure(let error):
                    let errorString = error.localizedDescription.lowercased()
                    Logger.shared.log("AniList progress update failed: \(errorString)", type: "Error")
                    
                    if errorString.contains("access token not found") {
                        Logger.shared.log("AniList update will NOT retry due to missing token.", type: "Error")
                        self.aniListUpdateImpossible = true
                        
                    } else {
                        if self.aniListRetryCount < self.aniListMaxRetries {
                            self.aniListRetryCount += 1
                            
                            let delaySeconds = 5.0
                            Logger.shared.log(
                                "AniList update will retry in \(delaySeconds)s " +
                                "(attempt \(self.aniListRetryCount)).",
                                type: "Debug"
                            )
                            
                            DispatchQueue.main.asyncAfter(deadline: .now() + delaySeconds) {
                                self.tryAniListUpdate()
                            }
                        } else {
                            Logger.shared.log(
                                "Reached max retry count (\(self.aniListMaxRetries)). Giving up.",
                                type: "Error"
                            )
                        }
                    }
                }
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
    
    private func animateButtonRotation(_ button: UIView, clockwise: Bool = true) {
        if button.layer.animation(forKey: "rotate360") != nil {
            return
        }
        button.superview?.layoutIfNeeded()
        
        button.layer.shouldRasterize = true
        button.layer.rasterizationScale = UIScreen.main.scale
        button.layer.allowsEdgeAntialiasing = true
        
        let rotation = CABasicAnimation(keyPath: "transform.rotation.z")
        rotation.fromValue = 0
        rotation.toValue   = CGFloat.pi * 2 * (clockwise ? 1 : -1)
        rotation.duration  = 0.43
        rotation.timingFunction = CAMediaTimingFunction(name: .linear)
        
        button.layer.add(rotation, forKey: "rotate360")
        
        DispatchQueue.main.asyncAfter(deadline: .now() + rotation.duration) {
            button.layer.shouldRasterize = false
        }
    }
    
    
    private func parseM3U8(url: URL, completion: @escaping () -> Void) {
        if url.scheme == "file" {
            URLSession.shared.dataTask(with: url) { [weak self] data, response, error in
                self?.processM3U8Data(data: data, url: url, completion: completion)
            }.resume()
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
        
        URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            self?.processM3U8Data(data: data, url: url, completion: completion)
        }.resume()
    }
    
    private func processM3U8Data(data: Data?, url: URL, completion: @escaping () -> Void) {
        guard let data = data,
              let content = String(data: data, encoding: .utf8) else {
            Logger.shared.log("Failed to load m3u8 file")
            DispatchQueue.main.async {
                self.qualities = []
                completion()
            }
            return
        }
        
        let lines = content.components(separatedBy: .newlines)
        var qualities: [(String, String)] = []
        
        qualities.append(("Auto (Recommended)", url.absoluteString))
        
        func getQualityName(for height: Int) -> String {
            switch height {
            case 1080...: return "\(height)p (FHD)"
            case 720..<1080: return "\(height)p (HD)"
            case 480..<720: return "\(height)p (SD)"
            default: return "\(height)p"
            }
        }
        
        for (index, line) in lines.enumerated() {
            if line.contains("#EXT-X-STREAM-INF"), index + 1 < lines.count {
                if let resolutionRange = line.range(of: "RESOLUTION="),
                   let resolutionEndRange = line[resolutionRange.upperBound...].range(of: ",")
                    ?? line[resolutionRange.upperBound...].range(of: "\n") {
                    
                    let resolutionPart = String(line[resolutionRange.upperBound..<resolutionEndRange.lowerBound])
                    if let heightStr = resolutionPart.components(separatedBy: "x").last,
                       let height = Int(heightStr) {
                        
                        let nextLine = lines[index + 1].trimmingCharacters(in: .whitespacesAndNewlines)
                        let qualityName = getQualityName(for: height)
                        
                        var qualityURL = nextLine
                        if !nextLine.hasPrefix("http") && nextLine.contains(".m3u8") {
                            if let baseURL = self.baseM3U8URL {
                                let baseURLString = baseURL.deletingLastPathComponent().absoluteString
                                qualityURL = URL(string: nextLine, relativeTo: baseURL)?.absoluteString
                                ?? baseURLString + "/" + nextLine
                            }
                        }
                        
                        if !qualities.contains(where: { $0.0 == qualityName }) {
                            qualities.append((qualityName, qualityURL))
                        }
                    }
                }
            }
        }
        
        DispatchQueue.main.async {
            let autoQuality = qualities.first
            var sortedQualities = qualities.dropFirst().sorted { first, second in
                let firstHeight = Int(first.0.components(separatedBy: CharacterSet.decimalDigits.inverted).joined()) ?? 0
                let secondHeight = Int(second.0.components(separatedBy: CharacterSet.decimalDigits.inverted).joined()) ?? 0
                return firstHeight > secondHeight
            }
            
            if let auto = autoQuality {
                sortedQualities.insert(auto, at: 0)
            }
            
            self.qualities = sortedQualities
            completion()
        }
    }
    
    private func switchToQuality(urlString: String) {
        guard let url = URL(string: urlString),
              currentQualityURL?.absoluteString != urlString else {
            Logger.shared.log("Quality Selection: Switch cancelled - same quality already selected", type: "General")
            return
        }
        
        let qualityName = qualities.first(where: { $0.1 == urlString })?.0 ?? "Unknown"
        Logger.shared.log("Quality Selection: Switching to quality: \(qualityName) (\(urlString))", type: "General")
        
        let currentTime = player.currentTime()
        let wasPlaying = player.rate > 0
        
        let asset: AVURLAsset
        
        if url.scheme == "file" {
            Logger.shared.log("Switching to local file: \(url.absoluteString)", type: "Debug")
            
            
            if FileManager.default.fileExists(atPath: url.path) {
                Logger.shared.log("Local file exists for quality switch: \(url.path)", type: "Debug")
            } else {
                Logger.shared.log("WARNING: Local file does not exist for quality switch: \(url.path)", type: "Error")
            }
            
            asset = AVURLAsset(url: url)
        } else {
            Logger.shared.log("Switching to remote URL: \(url.absoluteString)", type: "Debug")
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
            
            asset = AVURLAsset(url: url, options: ["AVURLAssetHTTPHeaderFieldsKey": request.allHTTPHeaderFields ?? [:]])
        }
        
        let playerItem = AVPlayerItem(asset: asset)
        
        playerItem.addObserver(self, forKeyPath: "status", options: [.new], context: &playerItemKVOContext)
        
        if let currentItem = player.currentItem {
            currentItem.removeObserver(self, forKeyPath: "status", context: &playerItemKVOContext)
        }
        
        player.replaceCurrentItem(with: playerItem)
        player.seek(to: currentTime)
        if wasPlaying {
            player.play()
        }
        
        currentQualityURL = url
        
        UserDefaults.standard.set(urlString, forKey: "lastSelectedQuality")
        qualityButton.menu = qualitySelectionMenu()
        
        if let selectedQuality = qualities.first(where: { $0.1 == urlString })?.0 {
            Logger.shared.log("Quality Selection: Successfully switched to: \(selectedQuality)", type: "General")
            DropManager.shared.showDrop(title: "Quality: \(selectedQuality)", subtitle: "", duration: 0.5, icon: UIImage(systemName: "eye"))
        } else {
            Logger.shared.log("Quality Selection: Switch completed but quality name not found in list", type: "General")
        }
    }
    
    private func qualitySelectionMenu() -> UIMenu {
        var menuItems: [UIMenuElement] = []
        
        if isHLSStream {
            if qualities.isEmpty {
                let loadingAction = UIAction(title: "Loading qualities...", attributes: .disabled) { _ in }
                menuItems.append(loadingAction)
            } else {
                var menuTitle = "Video Quality"
                if let currentURL = currentQualityURL?.absoluteString,
                   let selectedQuality = qualities.first(where: { $0.1 == currentURL })?.0 {
                    menuTitle = "Quality: \(selectedQuality)"
                }
                
                for (name, urlString) in qualities {
                    let isCurrentQuality = currentQualityURL?.absoluteString == urlString
                    
                    let action = UIAction(
                        title: name,
                        state: isCurrentQuality ? .on : .off,
                        handler: { [weak self] _ in
                            self?.switchToQuality(urlString: urlString)
                        }
                    )
                    menuItems.append(action)
                }
                
                return UIMenu(title: menuTitle, children: menuItems)
            }
        } else {
            let unavailableAction = UIAction(title: "Quality selection unavailable", attributes: .disabled) { _ in }
            menuItems.append(unavailableAction)
        }
        
        return UIMenu(title: "Video Quality", children: menuItems)
    }
    
    private func checkForHLSStream() {
        guard let url = URL(string: streamURL) else { return }
        Logger.shared.log("Checking for HLS stream: \(url.absoluteString)", type: "Debug")
        
        if url.absoluteString.contains(".m3u8") || url.absoluteString.contains(".m3u") {
            Logger.shared.log("HLS stream detected", type: "Debug")
            isHLSStream = true
            baseM3U8URL = url
            currentQualityURL = url
            
            let networkType = NetworkMonitor.getCurrentNetworkType()
            let networkTypeString = networkType == .wifi ? "WiFi" : networkType == .cellular ? "Cellular" : "Unknown"
            Logger.shared.log("Quality Selection: Detected network type: \(networkTypeString)", type: "General")
            
            parseM3U8(url: url) { [weak self] in
                guard let self = self else { return }
                
                Logger.shared.log("Quality Selection: Found \(self.qualities.count) available qualities", type: "General")
                for (index, quality) in self.qualities.enumerated() {
                    Logger.shared.log("Quality Selection: Available [\(index + 1)]: \(quality.0) - \(quality.1)", type: "General")
                }
                
                let preferredQuality = UserDefaults.getVideoQualityPreference()
                Logger.shared.log("Quality Selection: User preference for \(networkTypeString): \(preferredQuality.rawValue)", type: "General")
                
                if let selectedQuality = VideoQualityPreference.findClosestQuality(preferred: preferredQuality, availableQualities: self.qualities) {
                    Logger.shared.log("Quality Selection: Selected quality: \(selectedQuality.0) (URL: \(selectedQuality.1))", type: "General")
                    self.switchToQuality(urlString: selectedQuality.1)
                } else {
                    Logger.shared.log("Quality Selection: No matching quality found, using default", type: "General")
                    if let last = UserDefaults.standard.string(forKey: "lastSelectedQuality"),
                       self.qualities.contains(where: { $0.1 == last }) {
                        Logger.shared.log("Quality Selection: Falling back to last selected quality", type: "General")
                        self.switchToQuality(urlString: last)
                    } else if let firstQuality = self.qualities.first {
                        Logger.shared.log("Quality Selection: Falling back to first available quality: \(firstQuality.0)", type: "General")
                        self.switchToQuality(urlString: firstQuality.1)
                    }
                }
                
                DispatchQueue.main.async {
                    Logger.shared.log("Showing quality button on main thread", type: "Debug")
                    self.qualityButton.isHidden = false
                    self.qualityButton.menu = self.qualitySelectionMenu()
                    
                    self.setupControlButtonsContainer()
                    
                    UIView.animate(withDuration: 0.25, delay: 0, options: .curveEaseInOut) {
                        self.view.layoutIfNeeded()
                    }
                }
            }
        } else {
            Logger.shared.log("Not an HLS stream", type: "Debug")
            isHLSStream = false
            qualityButton.isHidden = true
            Logger.shared.log("Quality Selection: Non-HLS stream detected, quality selection unavailable", type: "General")
        }
    }
    
    func buildOptionsMenu() -> UIMenu {
        var menuElements: [UIMenuElement] = []
        
        if let subURL = subtitlesURL, !subURL.isEmpty {
            let subtitlesToggleAction = UIAction(title: "Toggle Subtitles") { [weak self] _ in
                guard let self = self else { return }
                self.subtitlesEnabled.toggle()
            }
            
            let foregroundActions = [
                UIAction(title: "White") { _ in
                    SubtitleSettingsManager.shared.update { settings in settings.foregroundColor = "white" }
                    self.loadSubtitleSettings()
                    self.updateSubtitleLabelAppearance()
                },
                UIAction(title: "Yellow") { _ in
                    SubtitleSettingsManager.shared.update { settings in settings.foregroundColor = "yellow" }
                    self.loadSubtitleSettings()
                    self.updateSubtitleLabelAppearance()
                },
                UIAction(title: "Green") { _ in
                    SubtitleSettingsManager.shared.update { settings in settings.foregroundColor = "green" }
                    self.loadSubtitleSettings()
                    self.updateSubtitleLabelAppearance()
                },
                UIAction(title: "Blue") { _ in
                    SubtitleSettingsManager.shared.update { settings in settings.foregroundColor = "blue" }
                    self.loadSubtitleSettings()
                    self.updateSubtitleLabelAppearance()
                },
                UIAction(title: "Red") { _ in
                    SubtitleSettingsManager.shared.update { settings in settings.foregroundColor = "red" }
                    self.loadSubtitleSettings()
                    self.updateSubtitleLabelAppearance()
                },
                UIAction(title: "Purple") { _ in
                    SubtitleSettingsManager.shared.update { settings in settings.foregroundColor = "purple" }
                    self.loadSubtitleSettings()
                    self.updateSubtitleLabelAppearance()
                }
            ]
            let colorMenu = UIMenu(title: "Subtitle Color", children: foregroundActions)
            
            let fontSizeActions = [
                UIAction(title: "16") { _ in
                    SubtitleSettingsManager.shared.update { settings in settings.fontSize = 16 }
                    self.loadSubtitleSettings()
                    self.updateSubtitleLabelAppearance()
                },
                UIAction(title: "18") { _ in
                    SubtitleSettingsManager.shared.update { settings in settings.fontSize = 18 }
                    self.loadSubtitleSettings()
                    self.updateSubtitleLabelAppearance()
                },
                UIAction(title: "20") { _ in
                    SubtitleSettingsManager.shared.update { settings in settings.fontSize = 20 }
                    self.loadSubtitleSettings()
                    self.updateSubtitleLabelAppearance()
                },
                UIAction(title: "22") { _ in
                    SubtitleSettingsManager.shared.update { settings in settings.fontSize = 22 }
                    self.loadSubtitleSettings()
                    self.updateSubtitleLabelAppearance()
                },
                UIAction(title: "24") { _ in
                    SubtitleSettingsManager.shared.update { settings in settings.fontSize = 24 }
                    self.loadSubtitleSettings()
                    self.updateSubtitleLabelAppearance()
                },
                UIAction(title: "Custom") { _ in self.presentCustomFontAlert() }
            ]
            let fontSizeMenu = UIMenu(title: "Font Size", children: fontSizeActions)
            
            let shadowActions = [
                UIAction(title: "None") { _ in
                    SubtitleSettingsManager.shared.update { settings in settings.shadowRadius = 0 }
                    self.loadSubtitleSettings()
                    self.updateSubtitleLabelAppearance()
                },
                UIAction(title: "Low") { _ in
                    SubtitleSettingsManager.shared.update { settings in settings.shadowRadius = 1 }
                    self.loadSubtitleSettings()
                    self.updateSubtitleLabelAppearance()
                },
                UIAction(title: "Medium") { _ in
                    SubtitleSettingsManager.shared.update { settings in settings.shadowRadius = 3 }
                    self.loadSubtitleSettings()
                    self.updateSubtitleLabelAppearance()
                },
                UIAction(title: "High") { _ in
                    SubtitleSettingsManager.shared.update { settings in settings.shadowRadius = 6 }
                    self.loadSubtitleSettings()
                    self.updateSubtitleLabelAppearance()
                }
            ]
            let shadowMenu = UIMenu(title: "Shadow Intensity", children: shadowActions)
            
            let backgroundActions = [
                UIAction(title: "Toggle") { _ in
                    SubtitleSettingsManager.shared.update { settings in settings.backgroundEnabled.toggle() }
                    self.loadSubtitleSettings()
                    self.updateSubtitleLabelAppearance()
                }
            ]
            let backgroundMenu = UIMenu(title: "Background", children: backgroundActions)
            
            let paddingActions = [
                UIAction(title: "10p") { _ in
                    SubtitleSettingsManager.shared.update { settings in settings.bottomPadding = 10 }
                    self.loadSubtitleSettings()
                },
                UIAction(title: "20p") { _ in
                    SubtitleSettingsManager.shared.update { settings in settings.bottomPadding = 20 }
                    self.loadSubtitleSettings()
                },
                UIAction(title: "30p") { _ in
                    SubtitleSettingsManager.shared.update { settings in settings.bottomPadding = 30 }
                    self.loadSubtitleSettings()
                },
                UIAction(title: "Custom") { _ in self.presentCustomPaddingAlert() }
            ]
            let paddingMenu = UIMenu(title: "Bottom Padding", children: paddingActions)
            
            let delayActions = [
                UIAction(title: "-0.5s") { [weak self] _ in
                    guard let self = self else { return }
                    self.adjustSubtitleDelay(by: -0.5)
                },
                UIAction(title: "-0.2s") { [weak self] _ in
                    guard let self = self else { return }
                    self.adjustSubtitleDelay(by: -0.2)
                },
                UIAction(title: "+0.2s") { [weak self] _ in
                    guard let self = self else { return }
                    self.adjustSubtitleDelay(by: 0.2)
                },
                UIAction(title: "+0.5s") { [weak self] _ in
                    guard let self = self else { return }
                    self.adjustSubtitleDelay(by: 0.5)
                },
                UIAction(title: "Custom...") { [weak self] _ in
                    guard let self = self else { return }
                    self.presentCustomDelayAlert()
                }
            ]
            
            let resetDelayAction = UIAction(title: "Reset Delay") { [weak self] _ in
                guard let self = self else { return }
                SubtitleSettingsManager.shared.update { settings in settings.subtitleDelay = 0.0 }
                self.subtitleDelay = 0.0
                self.loadSubtitleSettings()
            }
            
            let delayMenu = UIMenu(title: "Subtitle Delay", children: delayActions + [resetDelayAction])
            
            let subtitleOptionsMenu = UIMenu(title: "Subtitle Options", children: [
                subtitlesToggleAction, colorMenu, fontSizeMenu, shadowMenu, backgroundMenu, paddingMenu, delayMenu
            ])
            
            menuElements = [subtitleOptionsMenu]
        }
        
        return UIMenu(title: "", children: menuElements)
    }
    
    func adjustSubtitleDelay(by amount: Double) {
        let newValue = subtitleDelay + amount
        let roundedValue = Double(round(newValue * 10) / 10)
        SubtitleSettingsManager.shared.update { settings in settings.subtitleDelay = roundedValue }
        self.subtitleDelay = roundedValue
        self.loadSubtitleSettings()
    }
    
    func presentCustomDelayAlert() {
        let alert = UIAlertController(title: "Enter Custom Delay", message: nil, preferredStyle: .alert)
        alert.addTextField { textField in
            textField.placeholder = "Delay in seconds"
            textField.keyboardType = .decimalPad
            textField.text = String(format: "%.1f", self.subtitleDelay)
        }
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        alert.addAction(UIAlertAction(title: "Done", style: .default) { _ in
            if let text = alert.textFields?.first?.text, let newDelay = Double(text) {
                SubtitleSettingsManager.shared.update { settings in settings.subtitleDelay = newDelay }
                self.subtitleDelay = newDelay
                self.loadSubtitleSettings()
            }
        })
        present(alert, animated: true)
    }
    
    func presentCustomPaddingAlert() {
        let alert = UIAlertController(title: "Enter Custom Padding", message: nil, preferredStyle: .alert)
        alert.addTextField { textField in
            textField.placeholder = "Padding Value"
            textField.keyboardType = .numberPad
            textField.text = String(Int(self.subtitleBottomPadding))
        }
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: nil))
        alert.addAction(UIAlertAction(title: "Done", style: .default, handler: { _ in
            if let text = alert.textFields?.first?.text, let intValue = Int(text) {
                let newSize = CGFloat(intValue)
                SubtitleSettingsManager.shared.update { settings in settings.bottomPadding = newSize }
                self.loadSubtitleSettings()
            }
        }))
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            self.present(alert, animated: true, completion: nil)
        }
    }
    
    func presentCustomFontAlert() {
        let alert = UIAlertController(title: "Enter Custom Font Size", message: nil, preferredStyle: .alert)
        alert.addTextField { textField in
            textField.placeholder = "Font Size"
            textField.keyboardType = .numberPad
            textField.text = String(Int(self.subtitleFontSize))
        }
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: nil))
        alert.addAction(UIAlertAction(title: "Done", style: .default, handler: { _ in
            if let text = alert.textFields?.first?.text, let newSize = Double(text) {
                SubtitleSettingsManager.shared.update { settings in settings.fontSize = newSize }
                self.loadSubtitleSettings()
                self.updateSubtitleLabelAppearance()
            }
        }))
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            self.present(alert, animated: true, completion: nil)
        }
    }
    
    func loadSubtitleSettings() {
        let settings = SubtitleSettingsManager.shared.settings
        self.subtitleForegroundColor = settings.foregroundColor
        self.subtitleFontSize = settings.fontSize
        self.subtitleShadowRadius = settings.shadowRadius
        self.subtitleBackgroundEnabled = settings.backgroundEnabled
        self.subtitleBottomPadding = settings.bottomPadding
        self.subtitleDelay = settings.subtitleDelay
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
    
    func setupAudioSession() {
        do {
            let audioSession = AVAudioSession.sharedInstance()
            try audioSession.setCategory(.playback, mode: .moviePlayback, options: .mixWithOthers)
            try audioSession.setActive(true)
            try audioSession.overrideOutputAudioPort(.speaker)
        } catch {
            Logger.shared.log("Didn't set up AVAudioSession: \(error)", type: "Debug")
        }
        
        volumeObserver = audioSession.observe(\.outputVolume, options: [.new]) { [weak self] session, change in
            guard let newVol = change.newValue else { return }
            if let oldVol = self?.volumeViewModel.value, abs(Double(newVol) - oldVol) < 0.02 {
                return
            }
            DispatchQueue.main.async {
                self?.volumeViewModel.value = Double(newVol)
                Logger.shared.log("Hardware volume changed, new value: \(newVol)", type: "Debug")
            }
        }
    }
    
    private func setupHoldGesture() {
        holdGesture = UILongPressGestureRecognizer(target: self, action: #selector(handleHoldGesture(_:)))
        holdGesture?.minimumPressDuration = 0.5
        if let holdGesture = holdGesture {
            view.addGestureRecognizer(holdGesture)
        }
    }
    
    @objc private func handleHoldGesture(_ gesture: UILongPressGestureRecognizer) {
        switch gesture.state {
        case .began:
            beginHoldSpeed()
        case .ended, .cancelled:
            endHoldSpeed()
        default:
            break
        }
    }
    
    @objc private func handlePanGesture(_ gesture: UIPanGestureRecognizer) {
        let translation = gesture.translation(in: view)
        
        switch gesture.state {
        case .ended:
            if translation.y > 100 {
                dismiss(animated: true, completion: nil)
            }
        default:
            break
        }
    }
    
    private func beginHoldSpeed() {
        guard let player = player else { return }
        originalRate = player.rate
        let holdSpeed = UserDefaults.standard.float(forKey: "holdSpeedPlayer")
        let speed = holdSpeed > 0 ? holdSpeed : 2.0
        player.rate = speed
        
        UIView.animate(withDuration: 0.1) {
            self.holdSpeedIndicator.alpha = 1.0
        }
    }
    
    private func endHoldSpeed() {
        player?.rate = originalRate
        
        UIView.animate(withDuration: 0.2) {
            self.holdSpeedIndicator.alpha = 0
        }
    }
    
    private func setInitialPlayerRate() {
        if UserDefaults.standard.bool(forKey: "rememberPlaySpeed") {
            let lastPlayedSpeed = UserDefaults.standard.float(forKey: "lastPlaybackSpeed")
            player?.rate = lastPlayedSpeed > 0 ? lastPlayedSpeed : 1.0
        }
    }
    
    func setupTimeControlStatusObservation() {
        playerTimeControlStatusObserver = player.observe(\.timeControlStatus, options: [.new]) { [weak self] player, _ in
            guard self != nil else { return }
            if player.timeControlStatus == .paused,
               let reason = player.reasonForWaitingToPlay {
                Logger.shared.log("Paused reason: \(reason)", type: "Error")
                if reason == .toMinimizeStalls {
                    player.play()
                }
            }
        }
    }
    
    struct VolumeSliderContainer: View {
        @ObservedObject var volumeVM: VolumeViewModel
        var updateSystemSlider: ((Double) -> Void)? = nil
        
        var body: some View {
            VolumeSlider(
                value: Binding(
                    get: { volumeVM.value },
                    set: { newVal in
                        volumeVM.value = newVal
                        updateSystemSlider?(newVal)
                    }
                ),
                inRange: 0...1,
                activeFillColor: .white,
                fillColor: .white,
                emptyColor: .white.opacity(0.3),
                height: 10,
                onEditingChanged: { _ in }
            )
        }
    }
    
    func subtitleUIColor() -> UIColor {
        switch subtitleForegroundColor {
        case "white": return .white
        case "yellow": return .yellow
        case "green": return .green
        case "purple": return .purple
        case "blue": return .blue
        case "red": return .red
        default: return .white
        }
    }
    
    override var canBecomeFirstResponder: Bool {
        return true
    }
    
    override var keyCommands: [UIKeyCommand]? {
        return [
            UIKeyCommand(input: " ", modifierFlags: [], action: #selector(handleSpaceKey), discoverabilityTitle: "Play/Pause"),
            UIKeyCommand(input: UIKeyCommand.inputLeftArrow, modifierFlags: [], action: #selector(handleLeftArrow), discoverabilityTitle: "Seek Backward 10s"),
            UIKeyCommand(input: UIKeyCommand.inputRightArrow, modifierFlags: [], action: #selector(handleRightArrow), discoverabilityTitle: "Seek Forward 10s"),
            UIKeyCommand(input: UIKeyCommand.inputUpArrow, modifierFlags: [], action: #selector(handleUpArrow), discoverabilityTitle: "Seek Forward 60s"),
            UIKeyCommand(input: UIKeyCommand.inputDownArrow, modifierFlags: [], action: #selector(handleDownArrow), discoverabilityTitle: "Seek Backward 60s"),
            UIKeyCommand(input: UIKeyCommand.inputEscape, modifierFlags: [], action: #selector(handleEscape), discoverabilityTitle: "Dismiss Player")
        ]
    }
    
    @objc private func handleSpaceKey() {
        togglePlayPause()
    }
    
    @objc private func handleLeftArrow() {
        let skipValue = 10.0
        currentTimeVal = max(currentTimeVal - skipValue, 0)
        player.seek(to: CMTime(seconds: currentTimeVal, preferredTimescale: 600))
        animateButtonRotation(backwardButton, clockwise: false)
    }
    
    @objc private func handleRightArrow() {
        let skipValue = 10.0
        currentTimeVal = min(currentTimeVal + skipValue, duration)
        player.seek(to: CMTime(seconds: currentTimeVal, preferredTimescale: 600))
        animateButtonRotation(forwardButton)
    }
    
    @objc private func handleUpArrow() {
        let skipValue = 60.0
        currentTimeVal = min(currentTimeVal + skipValue, duration)
        player.seek(to: CMTime(seconds: currentTimeVal, preferredTimescale: 600))
        animateButtonRotation(forwardButton)
    }
    
    @objc private func handleDownArrow() {
        let skipValue = 60.0
        currentTimeVal = max(currentTimeVal - skipValue, 0)
        player.seek(to: CMTime(seconds: currentTimeVal, preferredTimescale: 600))
        animateButtonRotation(backwardButton, clockwise: false)
    }
    
    @objc private func handleEscape() {
        dismiss(animated: true, completion: nil)
    }
    
    private func setupTimeBatteryIndicator() {
        let container = UIView()
        container.translatesAutoresizingMaskIntoConstraints = false
        container.backgroundColor = .clear
        container.layer.cornerRadius = 8
        controlsContainerView.addSubview(container)
        self.timeBatteryContainer = container
        
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(toggleEndTimeVisibility))
        container.addGestureRecognizer(tapGesture)
        container.isUserInteractionEnabled = true
        
        let endTimeIcon = UIImageView(image: UIImage(systemName: "timer"))
        endTimeIcon.translatesAutoresizingMaskIntoConstraints = false
        endTimeIcon.tintColor = .white
        endTimeIcon.contentMode = .scaleAspectFit
        endTimeIcon.alpha = 0
        container.addSubview(endTimeIcon)
        self.endTimeIcon = endTimeIcon
        
        let endTimeLabel = UILabel()
        endTimeLabel.translatesAutoresizingMaskIntoConstraints = false
        endTimeLabel.textColor = .white
        endTimeLabel.font = .systemFont(ofSize: 12, weight: .medium)
        endTimeLabel.textAlignment = .center
        endTimeLabel.alpha = 0
        container.addSubview(endTimeLabel)
        self.endTimeLabel = endTimeLabel
        
        let endTimeSeparator = UIView()
        endTimeSeparator.translatesAutoresizingMaskIntoConstraints = false
        endTimeSeparator.backgroundColor = .white.withAlphaComponent(0.5)
        endTimeSeparator.alpha = 0
        container.addSubview(endTimeSeparator)
        self.endTimeSeparator = endTimeSeparator
        
        let timeLabel = UILabel()
        timeLabel.translatesAutoresizingMaskIntoConstraints = false
        timeLabel.textColor = .white
        timeLabel.font = .systemFont(ofSize: 12, weight: .medium)
        timeLabel.textAlignment = .center
        container.addSubview(timeLabel)
        self.timeLabel = timeLabel
        
        let separator = UIView()
        separator.translatesAutoresizingMaskIntoConstraints = false
        separator.backgroundColor = .white.withAlphaComponent(0.5)
        container.addSubview(separator)
        
        let batteryLabel = UILabel()
        batteryLabel.translatesAutoresizingMaskIntoConstraints = false
        batteryLabel.textColor = .white
        batteryLabel.font = .systemFont(ofSize: 12, weight: .medium)
        batteryLabel.textAlignment = .center
        container.addSubview(batteryLabel)
        self.batteryLabel = batteryLabel
        
        let centerXConstraint = container.centerXAnchor.constraint(equalTo: controlsContainerView.centerXAnchor)
        centerXConstraint.isActive = true
        
        NSLayoutConstraint.activate([
            container.topAnchor.constraint(equalTo: sliderHostingController?.view.bottomAnchor ?? controlsContainerView.bottomAnchor, constant: 2),
            container.heightAnchor.constraint(equalToConstant: 20),
            
            endTimeIcon.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 12),
            endTimeIcon.centerYAnchor.constraint(equalTo: container.centerYAnchor),
            endTimeIcon.widthAnchor.constraint(equalToConstant: 12),
            endTimeIcon.heightAnchor.constraint(equalToConstant: 12),
            
            endTimeLabel.leadingAnchor.constraint(equalTo: endTimeIcon.trailingAnchor, constant: 4),
            endTimeLabel.centerYAnchor.constraint(equalTo: container.centerYAnchor),
            endTimeLabel.widthAnchor.constraint(equalToConstant: 50),
            
            endTimeSeparator.leadingAnchor.constraint(equalTo: endTimeLabel.trailingAnchor, constant: 8),
            endTimeSeparator.centerYAnchor.constraint(equalTo: container.centerYAnchor),
            endTimeSeparator.widthAnchor.constraint(equalToConstant: 1),
            endTimeSeparator.heightAnchor.constraint(equalToConstant: 12),
            
            timeLabel.leadingAnchor.constraint(equalTo: endTimeSeparator.trailingAnchor, constant: 8),
            timeLabel.centerYAnchor.constraint(equalTo: container.centerYAnchor),
            timeLabel.widthAnchor.constraint(equalToConstant: 50),
            
            separator.leadingAnchor.constraint(equalTo: timeLabel.trailingAnchor, constant: 8),
            separator.centerYAnchor.constraint(equalTo: container.centerYAnchor),
            separator.widthAnchor.constraint(equalToConstant: 1),
            separator.heightAnchor.constraint(equalToConstant: 12),
            
            batteryLabel.leadingAnchor.constraint(equalTo: separator.trailingAnchor, constant: 8),
            batteryLabel.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -12),
            batteryLabel.centerYAnchor.constraint(equalTo: container.centerYAnchor),
            batteryLabel.widthAnchor.constraint(equalToConstant: 50)
        ])
        
        isEndTimeVisible = UserDefaults.standard.bool(forKey: "showEndTime")
        updateEndTimeVisibility(animated: false)
        
        updateTime()
        updateEndTime()
        timeUpdateTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.updateTime()
            self?.updateEndTime()
        }
        
        UIDevice.current.isBatteryMonitoringEnabled = true
        updateBatteryLevel()
        NotificationCenter.default.addObserver(self, selector: #selector(batteryLevelDidChange), name: UIDevice.batteryLevelDidChangeNotification, object: nil)
    }
    
    @objc private func toggleEndTimeVisibility() {
        isEndTimeVisible.toggle()
        UserDefaults.standard.set(isEndTimeVisible, forKey: "showEndTime")
        updateEndTimeVisibility(animated: true)
    }
    
    private func updateEndTimeVisibility(animated: Bool) {
        let alpha: CGFloat = isEndTimeVisible ? 1.0 : 0.0
        let offset: CGFloat = isEndTimeVisible ? 0 : -37
        
        if animated {
            UIView.animate(withDuration: 0.3) {
                self.endTimeIcon?.alpha = alpha
                self.endTimeSeparator?.alpha = alpha
                self.endTimeLabel?.alpha = alpha
                
                if let container = self.timeBatteryContainer {
                    container.transform = CGAffineTransform(translationX: offset, y: 0)
                }
            }
        } else {
            self.endTimeIcon?.alpha = alpha
            self.endTimeSeparator?.alpha = alpha
            self.endTimeLabel?.alpha = alpha
            
            if let container = self.timeBatteryContainer {
                container.transform = CGAffineTransform(translationX: offset, y: 0)
            }
        }
    }
    
    private func updateTime() {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        timeLabel?.text = formatter.string(from: Date())
    }
    
    private func updateEndTime() {
        guard let player = player, duration > 0 else { return }
        
        let currentSeconds = CMTimeGetSeconds(player.currentTime())
        let remainingSeconds = duration - currentSeconds
        let playbackSpeed = player.rate
        
        if remainingSeconds <= 0 {
            endTimeLabel?.text = "--:--"
            return
        }
        
        if playbackSpeed == 0 {
            let endTime = Date().addingTimeInterval(remainingSeconds)
            let formatter = DateFormatter()
            formatter.dateFormat = "HH:mm"
            endTimeLabel?.text = formatter.string(from: endTime)
            return
        }
        
        let realTimeRemaining = remainingSeconds / Double(playbackSpeed)
        let endTime = Date().addingTimeInterval(realTimeRemaining)
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        endTimeLabel?.text = formatter.string(from: endTime)
    }
    
    @objc private func batteryLevelDidChange() {
        updateBatteryLevel()
    }
    
    private func updateBatteryLevel() {
        let batteryLevel = UIDevice.current.batteryLevel
        if batteryLevel >= 0 {
            let percentage = Int(batteryLevel * 100)
            batteryLabel?.text = "\(percentage)%"
        } else {
            batteryLabel?.text = "N/A"
        }
    }
    
    @objc private func handlePlaybackEnded() {
        guard isAutoplayEnabled else { return }
        
        Logger.shared.log("Playback ended, autoplay enabled - starting next episode", type: "Debug")
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
            self?.player.pause()
            self?.dismiss(animated: true) { [weak self] in
                self?.onWatchNext()
            }
        }
    }
    
    
    
    @objc private func protectMenuFromRecreation() {
        isMenuOpen = true
    }
    
    func setupWatchNextButton() {
        let image = UIImage(systemName: "forward.end", withConfiguration: cfg)
        
        watchNextButton = UIButton(type: .system)
        watchNextButton.setImage(image, for: .normal)
        watchNextButton.backgroundColor = .clear
        watchNextButton.tintColor = .white
        watchNextButton.setTitleColor(.white, for: .normal)
        watchNextButton.addTarget(self, action: #selector(watchNextTapped), for: .touchUpInside)
        watchNextButton.translatesAutoresizingMaskIntoConstraints = false
    }
    
    private func setupDimButton() {
        dimButton = UIButton(type: .system)
        dimButton.setImage(UIImage(systemName: "moon", withConfiguration: cfg), for: .normal)
        dimButton.tintColor = .white
        dimButton.addTarget(self, action: #selector(dimTapped), for: .touchUpInside)
        view.addSubview(dimButton)
        dimButton.translatesAutoresizingMaskIntoConstraints = false
        
        NSLayoutConstraint.activate([
            dimButton.centerYAnchor.constraint(equalTo: dismissButton.centerYAnchor),
            dimButton.widthAnchor.constraint(equalToConstant: 24),
            dimButton.heightAnchor.constraint(equalToConstant: 24)  
        ])
        
        dimButtonToSlider = dimButton.trailingAnchor.constraint(equalTo: volumeSliderHostingView!.trailingAnchor)
        dimButtonToRight = dimButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16)
    }
    
    func setupSpeedButton() {
        let image = UIImage(systemName: "speedometer", withConfiguration: bottomControlsCfg)
        
        speedButton = UIButton(type: .system)
        speedButton.setImage(image, for: .normal)
        speedButton.tintColor = .white
        speedButton.showsMenuAsPrimaryAction = true
        speedButton.menu = speedChangerMenu()
        
        speedButton.addTarget(self, action: #selector(protectMenuFromRecreation), for: .touchDown)
        
        speedButton.translatesAutoresizingMaskIntoConstraints = false
    }
    
    func setupMenuButton() {
        let image = UIImage(systemName: "captions.bubble", withConfiguration: bottomControlsCfg)
        
        menuButton = UIButton(type: .system)
        menuButton.setImage(image, for: .normal)
        menuButton.tintColor = .white
        menuButton.showsMenuAsPrimaryAction = true
        
        if let subtitlesURL = subtitlesURL, !subtitlesURL.isEmpty {
            menuButton.menu = buildOptionsMenu()
        } else {
            menuButton.isHidden = true
        }
        
        menuButton.addTarget(self, action: #selector(protectMenuFromRecreation), for: .touchDown)
        
        menuButton.translatesAutoresizingMaskIntoConstraints = false
    }
    
    private func setupLockButton() {
        lockButton = UIButton(type: .system)
        lockButton.setImage(
            UIImage(systemName: "lock.open", withConfiguration: cfg),
            for: .normal
        )
        lockButton.tintColor = .white
        
        lockButton.addTarget(self, action: #selector(lockTapped), for: .touchUpInside)
        
        view.addSubview(lockButton)
        lockButton.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            lockButton.centerYAnchor.constraint(equalTo: dismissButton.centerYAnchor),
            lockButton.widthAnchor.constraint(equalToConstant: 24),
            lockButton.heightAnchor.constraint(equalToConstant: 24),
        ])
    }
    
    private func setupUnlockButton() {
        let config = UIImage.SymbolConfiguration(pointSize: 30, weight: .medium)
        unlockButton = UIButton(type: .system)
        unlockButton.setImage(
            UIImage(systemName: "lock", withConfiguration: config),
            for: .normal
        )
        unlockButton.tintColor = .white
        unlockButton.alpha = 0
        unlockButton.layer.shadowColor = UIColor.black.cgColor
        unlockButton.layer.shadowOffset = CGSize(width: 0, height: 2)
        unlockButton.layer.shadowOpacity = 0.6
        unlockButton.layer.shadowRadius = 4
        unlockButton.layer.masksToBounds = false
        
        unlockButton.addTarget(self, action: #selector(lockTapped), for: .touchUpInside)
        
        view.addSubview(unlockButton)
        unlockButton.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            unlockButton.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            unlockButton.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor),
            unlockButton.widthAnchor.constraint(equalToConstant: 60),
            unlockButton.heightAnchor.constraint(equalToConstant: 60)
        ])
    }
    
    private func setupPipIfSupported() {
        airplayButton = AVRoutePickerView(frame: .zero)
        airplayButton.translatesAutoresizingMaskIntoConstraints = false
        airplayButton.activeTintColor = .white
        airplayButton.tintColor = .white
        airplayButton.backgroundColor = .clear
        airplayButton.prioritizesVideoDevices = true
        airplayButton.setContentHuggingPriority(.required, for: .horizontal)
        airplayButton.setContentCompressionResistancePriority(.required, for: .horizontal)
        
        let airplayContainer = UIView()
        airplayContainer.translatesAutoresizingMaskIntoConstraints = false
        airplayContainer.backgroundColor = .clear
        view.addSubview(airplayContainer)
        airplayContainer.addSubview(airplayButton)
        
        NSLayoutConstraint.activate([
            airplayContainer.widthAnchor.constraint(equalToConstant: 24),
            airplayContainer.heightAnchor.constraint(equalToConstant: 24),
            airplayButton.centerXAnchor.constraint(equalTo: airplayContainer.centerXAnchor),
            airplayButton.centerYAnchor.constraint(equalTo: airplayContainer.centerYAnchor),
            airplayButton.widthAnchor.constraint(equalToConstant: 24),
            airplayButton.heightAnchor.constraint(equalToConstant: 24)
        ])
        
        for subview in airplayButton.subviews {
            subview.contentMode = .scaleAspectFit
            if let button = subview as? UIButton {
                button.imageEdgeInsets = .zero
                button.contentEdgeInsets = .zero
            }
        }
        
        guard AVPictureInPictureController.isPictureInPictureSupported() else {
            return
        }
        
        playerViewController.allowsPictureInPicturePlayback = true
        
        let playerLayerContainer = UIView()
        playerLayerContainer.translatesAutoresizingMaskIntoConstraints = false
        view.insertSubview(playerLayerContainer, at: 0)
        
        NSLayoutConstraint.activate([
            playerLayerContainer.topAnchor.constraint(equalTo: view.topAnchor),
            playerLayerContainer.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            playerLayerContainer.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            playerLayerContainer.trailingAnchor.constraint(equalTo: view.trailingAnchor)
        ])
        
        let playerLayer = AVPlayerLayer(player: player)
        playerLayer.frame = playerLayerContainer.bounds
        playerLayer.videoGravity = .resizeAspect
        playerLayerContainer.layer.addSublayer(playerLayer)
        
        pipController = AVPictureInPictureController(playerLayer: playerLayer)
        pipController?.delegate = self
        
        let Image = UIImage(systemName: "pip", withConfiguration: cfg)
        pipButton = UIButton(type: .system)
        pipButton.setImage(Image, for: .normal)
        pipButton.tintColor = .white
        pipButton.addTarget(self, action: #selector(pipButtonTapped(_:)), for: .touchUpInside)
        
        controlsContainerView.addSubview(pipButton)
        pipButton.translatesAutoresizingMaskIntoConstraints = false
        
        NSLayoutConstraint.activate([
            pipButton.centerYAnchor.constraint(equalTo: dimButton.centerYAnchor),
            pipButton.trailingAnchor.constraint(equalTo: dimButton.leadingAnchor, constant: -8),
            pipButton.widthAnchor.constraint(equalToConstant: 24),  
            pipButton.heightAnchor.constraint(equalToConstant: 24), 
            airplayButton.centerYAnchor.constraint(equalTo: pipButton.centerYAnchor),
            airplayButton.trailingAnchor.constraint(equalTo: pipButton.leadingAnchor, constant: -4),
            airplayButton.widthAnchor.constraint(equalToConstant: 24),
            airplayButton.heightAnchor.constraint(equalToConstant: 24)
        ])
        
        pipButton.isHidden = !isPipButtonVisible
        
        NotificationCenter.default.addObserver(self, selector: #selector(startPipIfNeeded), name: UIApplication.willResignActiveNotification, object: nil)
    }
    
    func updateMarqueeConstraints() {
        titleStackView.isHidden = false
        episodeNumberLabel.isHidden = false
        titleLabel.isHidden = false
        
        titleStackView.alpha = 1.0
        episodeNumberLabel.alpha = 1.0
        titleLabel.alpha = 1.0
        
        titleLabel.textAlignment = .left
        episodeNumberLabel.textAlignment = .left
        
        view.layoutIfNeeded()
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            self.titleLabel.restartLabel()
        }
    }
    
    private func resetMarqueeAfterOrientationChange() {
        let forcedLandscape = UserDefaults.standard.bool(forKey: "alwaysLandscape")
        let isLandscape = forcedLandscape || view.bounds.width > view.bounds.height
        
        episodeNumberLabel.isHidden = !isLandscape
        titleLabel.isHidden = !isLandscape
        titleStackView.isHidden = !isLandscape
        
        episodeNumberLabel.alpha = isLandscape ? 1.0 : 0.0
        titleLabel.alpha = isLandscape ? 1.0 : 0.0
        titleStackView.alpha = isLandscape ? 1.0 : 0.0
        
        if !isLandscape {
            return
        }
        
        titleLabel.textAlignment = .left
        episodeNumberLabel.textAlignment = .left
        
        view.setNeedsLayout()
        view.layoutIfNeeded()
        
        titleLabel.shutdownLabel()
        if isLandscape {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                self.titleLabel.restartLabel()
            }
        }
    }
}

class GradientOverlayButton: UIButton {
    private let gradientLayer = CAGradientLayer()
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupGradient()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupGradient()
    }
    
    private func setupGradient() {
        gradientLayer.colors = [
            UIColor.white.withAlphaComponent(0.25).cgColor,
            UIColor.white.withAlphaComponent(0).cgColor
        ]
        gradientLayer.startPoint = CGPoint(x: 0.5, y: 0)
        gradientLayer.endPoint = CGPoint(x: 0.5, y: 1)
        layer.addSublayer(gradientLayer)
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        gradientLayer.frame = bounds
        
        let path = UIBezierPath(roundedRect: bounds.insetBy(dx: 0.25, dy: 0.25), cornerRadius: bounds.height / 2)
        let maskLayer = CAShapeLayer()
        maskLayer.path = path.cgPath
        maskLayer.fillColor = nil
        maskLayer.strokeColor = UIColor.white.cgColor
        maskLayer.lineWidth = 0.5
        gradientLayer.mask = maskLayer
    }
}

extension CustomMediaPlayerViewController: AVPictureInPictureControllerDelegate {
    func pictureInPictureControllerWillStartPictureInPicture(_ pipController: AVPictureInPictureController) {
        pipButton.alpha = 0.5
    }
    
    func pictureInPictureControllerDidStopPictureInPicture(_ pipController: AVPictureInPictureController) {
        pipButton.alpha = 1.0
    }
    
    func pictureInPictureController(_ pipController: AVPictureInPictureController, failedToStartPictureInPictureWithError error: Error) {
        Logger.shared.log("PiP failed to start: \(error.localizedDescription)", type: "Error")
    }
}

extension CustomMediaPlayerViewController {
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        return true
    }
}

// yes? Like the plural of the famous american rapper ye? -IBHRAD
// low taper fade the meme is massive -cranci
// The mind is the source of good and evil, only you yourself can decide which you will bring yourself. -seiike
// guys watch Clannad already - ibro
// May the Divine Providence bestow its infinite mercy upon your soul, and may eternal grace find you beyond the shadows of this mortal realm. - paul, 15/11/2005 - 13/05/2023
// this dumbass ↑ defo used gpt, ong he did bro
// A view that passes through touches to views behind it unless the touch hits a subview
// fuck yall stories, continue below this code

class PassthroughView: UIView {
    override func point(inside point: CGPoint, with event: UIEvent?) -> Bool {
        for subview in subviews {
            if !subview.isHidden && subview.alpha > 0 && subview.isUserInteractionEnabled && subview.point(inside: convert(point, to: subview), with: event) {
                return true
            }
        }
        return false
    }
}

class GradientBlurButton: UIButton {
    private var gradientLayer: CAGradientLayer?
    private var borderMask: CAShapeLayer?
    private var blurView: UIVisualEffectView?
    private var storedTitle: String?
    private var storedImage: UIImage?
    
    override var isHidden: Bool {
        didSet {
            updateVisualState()
        }
    }
    
    override var alpha: CGFloat {
        didSet {
            updateVisualState()
        }
    }
    
    private func updateVisualState() {
        let shouldBeVisible = !isHidden && alpha > 0.1
        
        storedTitle = self.title(for: .normal)
        storedImage = self.image(for: .normal)
        
        cleanupVisualEffects()
        
        if shouldBeVisible {
            setupBlurAndGradient()
        } else {
            backgroundColor = .clear
        }
        
        if let title = storedTitle, !title.isEmpty {
            setTitle(title, for: .normal)
        }
        if let image = storedImage {
            setImage(image, for: .normal)
        }
    }
    
    private func cleanupVisualEffects() {
        blurView?.removeFromSuperview()
        blurView = nil
        
        backgroundColor = .clear
        layer.borderWidth = 0
        layer.shadowOpacity = 0
        layer.cornerRadius = 0
        clipsToBounds = false
    }
    
    override func willMove(toSuperview newSuperview: UIView?) {
        super.willMove(toSuperview: newSuperview)
        if newSuperview == nil {
            cleanupVisualEffects()
        } else if newSuperview != nil && !isHidden && alpha > 0.1 {
            setupBlurAndGradient()
        } else if newSuperview != nil {
            cleanupVisualEffects()
        }
    }
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        if !isHidden && alpha > 0.1 {
            setupBlurAndGradient()
        }
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        if !isHidden && alpha > 0.1 {
            setupBlurAndGradient()
        }
    }
    
    private func setupBlurAndGradient() {
        let blur = UIVisualEffectView(effect: UIBlurEffect(style: .systemUltraThinMaterial))
        blur.isUserInteractionEnabled = false
        blur.layer.cornerRadius = 21
        blur.clipsToBounds = true
        blur.translatesAutoresizingMaskIntoConstraints = false
        insertSubview(blur, at: 0)
        NSLayoutConstraint.activate([
            blur.leadingAnchor.constraint(equalTo: leadingAnchor),
            blur.trailingAnchor.constraint(equalTo: trailingAnchor),
            blur.topAnchor.constraint(equalTo: topAnchor),
            blur.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])
        self.blurView = blur
        
        clipsToBounds = true
        layer.cornerRadius = 21
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        
        if let imageView = self.imageView {
            bringSubviewToFront(imageView)
        }
        if let titleLabel = self.titleLabel {
            bringSubviewToFront(titleLabel)
        }
    }
    
    override func removeFromSuperview() {
        cleanupVisualEffects()
        super.removeFromSuperview()
    }
}
