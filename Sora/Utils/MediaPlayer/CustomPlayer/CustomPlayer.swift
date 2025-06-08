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
    
    private var aniListUpdatedSuccessfully = false
    private var aniListUpdateImpossible: Bool = false
    private var aniListRetryCount = 0
    private let aniListMaxRetries = 6
    private let totalEpisodes: Int
    
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
    private var pipController: AVPictureInPictureController?
    private var pipButton: UIButton!
    
    
    var portraitButtonVisibleConstraints: [NSLayoutConstraint] = []
    var portraitButtonHiddenConstraints: [NSLayoutConstraint] = []
    var landscapeButtonVisibleConstraints: [NSLayoutConstraint] = []
    var landscapeButtonHiddenConstraints: [NSLayoutConstraint] = []
    var currentMarqueeConstraints: [NSLayoutConstraint] = []
    private var currentMenuButtonTrailing: NSLayoutConstraint!
    
    
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
    
    var marqueeLabel: MarqueeLabel!
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
    
    private lazy var controlsToHide: [UIView] = [
        dismissButton,
        playPauseButton,
        backwardButton,
        forwardButton,
        sliderHostingController?.view,
        skip85Button,
        marqueeLabel,
        menuButton,
        qualityButton,
        speedButton,
        watchNextButton,
        volumeSliderHostingView,
        pipButton,
        airplayButton,
        audioTrackButton
    ].compactMap { $0 }
    
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
    
    private var audioTracks: [(name: String, groupID: String, uri: String)] = []
    private var audioTrackButton: UIButton!
    private var lastSelectedAudioTrack: String?
    
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
        self.player = AVPlayer(playerItem: playerItem)
        
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
        setupAudioMenuButton()
        setupMenuButton()
        setupMarqueeLabel()
        setupSkip85Button()
        setupSkipButtons()
        setupSkipAndDismissGestures()
        addTimeObserver()
        startUpdateTimer()
        setupLockButton()
        setupAudioSession()
        updateSkipButtonsVisibility()
        setupHoldSpeedIndicator()
        setupPipIfSupported()
        
        view.bringSubviewToFront(subtitleStackView)
        
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
        
        controlsToHide.forEach { originalHiddenStates[$0] = $0.isHidden }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            self?.checkForHLSStream()
        }
        
        if isHoldPauseEnabled {
            holdForPause()
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
    }
    
    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        super.viewWillTransition(to: size, with: coordinator)
        coordinator.animate(alongsideTransition: { _ in
            self.updateMarqueeConstraints()
        })
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        
        guard let marqueeLabel = marqueeLabel else {
            return
        }
        
        let availableWidth = marqueeLabel.frame.width
        let textWidth = marqueeLabel.intrinsicContentSize.width
        
        if textWidth > availableWidth {
            marqueeLabel.lineBreakMode = .byTruncatingTail
        } else {
            marqueeLabel.lineBreakMode = .byClipping
        }
        updateMenuButtonConstraints()
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
        playerRateObserver?.invalidate()
        inactivityTimer?.invalidate()
        updateTimer?.invalidate()
        lockButtonTimer?.invalidate()
        dimButtonTimer?.invalidate()
        loadedTimeRangesObservation?.invalidate()
        playerTimeControlStatusObserver?.invalidate()
        volumeObserver?.invalidate()
        
        player.replaceCurrentItem(with: nil)
        player.pause()
        
        playerViewController = nil
        sliderHostingController = nil
        try? AVAudioSession.sharedInstance().setActive(false)
    }
    
    override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?) {
        guard context == &playerItemKVOContext else {
            super.observeValue(forKeyPath: keyPath, of: object, change: change, context: context)
            return
        }
        
        if keyPath == "loadedTimeRanges" {
        }
    }
    
    
    @objc private func playerItemDidChange() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            if self.qualityButton.isHidden && self.isHLSStream {
                self.qualityButton.isHidden = false
                self.qualityButton.menu = self.qualitySelectionMenu()
                
                self.updateMenuButtonConstraints()
                
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
        view.addSubview(playerViewController.view)
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
    }
    
    func setupControls() {
        controlsContainerView = UIView()
        controlsContainerView.backgroundColor = UIColor.black.withAlphaComponent(0.0)
        view.addSubview(controlsContainerView)
        controlsContainerView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            controlsContainerView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            controlsContainerView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor),
            controlsContainerView.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor),
            controlsContainerView.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor)
        ])
        
        blackCoverView = UIView()
        blackCoverView.backgroundColor = UIColor.black.withAlphaComponent(0.4)
        blackCoverView.translatesAutoresizingMaskIntoConstraints = false
        controlsContainerView.insertSubview(blackCoverView, at: 0)
        NSLayoutConstraint.activate([
            blackCoverView.topAnchor.constraint(equalTo: view.topAnchor),
            blackCoverView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            blackCoverView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            blackCoverView.trailingAnchor.constraint(equalTo: view.trailingAnchor)
        ])
        
        backwardButton = UIImageView(image: UIImage(systemName: "gobackward"))
        backwardButton.tintColor = .white
        backwardButton.contentMode = .scaleAspectFit
        backwardButton.isUserInteractionEnabled = true
        
        backwardButton.layer.shadowColor = UIColor.black.cgColor
        backwardButton.layer.shadowOffset = CGSize(width: 0, height: 2)
        backwardButton.layer.shadowOpacity = 0.6
        backwardButton.layer.shadowRadius = 4
        backwardButton.layer.masksToBounds = false
        
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
        
        playPauseButton.layer.shadowColor = UIColor.black.cgColor
        playPauseButton.layer.shadowOffset = CGSize(width: 0, height: 2)
        playPauseButton.layer.shadowOpacity = 0.6
        playPauseButton.layer.shadowRadius = 4
        playPauseButton.layer.masksToBounds = false
        
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
        
        forwardButton.layer.shadowColor = UIColor.black.cgColor
        forwardButton.layer.shadowOffset = CGSize(width: 0, height: 2)
        forwardButton.layer.shadowOpacity = 0.6
        forwardButton.layer.shadowRadius = 4
        forwardButton.layer.masksToBounds = false
        
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
            fillColor: .white.opacity(0.6),
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
            playPauseButton.centerXAnchor.constraint(equalTo: controlsContainerView.centerXAnchor),
            playPauseButton.centerYAnchor.constraint(equalTo: controlsContainerView.centerYAnchor),
            playPauseButton.widthAnchor.constraint(equalToConstant: 50),
            playPauseButton.heightAnchor.constraint(equalToConstant: 50),
            
            backwardButton.centerYAnchor.constraint(equalTo: playPauseButton.centerYAnchor),
            backwardButton.trailingAnchor.constraint(equalTo: playPauseButton.leadingAnchor, constant: -50),
            backwardButton.widthAnchor.constraint(equalToConstant: 40),
            backwardButton.heightAnchor.constraint(equalToConstant: 40),
            
            forwardButton.centerYAnchor.constraint(equalTo: playPauseButton.centerYAnchor),
            forwardButton.leadingAnchor.constraint(equalTo: playPauseButton.trailingAnchor, constant: 50),
            forwardButton.widthAnchor.constraint(equalToConstant: 40),
            forwardButton.heightAnchor.constraint(equalToConstant: 40)
        ])
    }
    
    func holdForPause() {
        let holdForPauseGesture = UILongPressGestureRecognizer(target: self, action: #selector(handleHoldForPause(_:)))
        holdForPauseGesture.minimumPressDuration = 1
        holdForPauseGesture.numberOfTouchesRequired = 2
        view.addGestureRecognizer(holdForPauseGesture)
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
        let config = UIImage.SymbolConfiguration(pointSize: 15, weight: .bold)
        let image = UIImage(systemName: "xmark", withConfiguration: config)
        
        dismissButton = UIButton(type: .system)
        dismissButton.setImage(image, for: .normal)
        dismissButton.tintColor = .white
        dismissButton.addTarget(self, action: #selector(dismissTapped), for: .touchUpInside)
        controlsContainerView.addSubview(dismissButton)
        dismissButton.translatesAutoresizingMaskIntoConstraints = false
        
        dismissButton.layer.shadowColor = UIColor.black.cgColor
        dismissButton.layer.shadowOffset = CGSize(width: 0, height: 2)
        dismissButton.layer.shadowOpacity = 0.6
        dismissButton.layer.shadowRadius = 4
        dismissButton.layer.masksToBounds = false
        
        NSLayoutConstraint.activate([
            dismissButton.leadingAnchor.constraint(equalTo: controlsContainerView.leadingAnchor, constant: 16),
            dismissButton.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 20),
            dismissButton.widthAnchor.constraint(equalToConstant: 40),
            dismissButton.heightAnchor.constraint(equalToConstant: 40)
        ])
    }
    
    func setupMarqueeLabel() {
        marqueeLabel = MarqueeLabel()
        marqueeLabel.text = "\(titleText) • Ep \(episodeNumber)"
        marqueeLabel.type = .continuous
        marqueeLabel.textColor = .white
        marqueeLabel.font = UIFont.systemFont(ofSize: 14, weight: .heavy)
        
        marqueeLabel.speed = .rate(35)
        marqueeLabel.fadeLength = 10.0
        marqueeLabel.leadingBuffer = 1.0
        marqueeLabel.trailingBuffer = 16.0
        marqueeLabel.animationDelay = 2.5
        
        marqueeLabel.layer.shadowColor = UIColor.black.cgColor
        marqueeLabel.layer.shadowOffset = CGSize(width: 0, height: 2)
        marqueeLabel.layer.shadowOpacity = 0.6
        marqueeLabel.layer.shadowRadius = 4
        marqueeLabel.layer.masksToBounds = false
        
        marqueeLabel.lineBreakMode = .byTruncatingTail
        marqueeLabel.textAlignment = .left
        
        controlsContainerView.addSubview(marqueeLabel)
        marqueeLabel.translatesAutoresizingMaskIntoConstraints = false
        
        updateMarqueeConstraints()
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
        
        controlsContainerView.addSubview(hostingController.view)
        addChild(hostingController)
        hostingController.didMove(toParent: self)
        
        self.volumeSliderHostingView = hostingController.view
        
        NSLayoutConstraint.activate([
            hostingController.view.centerYAnchor.constraint(equalTo: dismissButton.centerYAnchor),
            hostingController.view.trailingAnchor.constraint(equalTo: controlsContainerView.trailingAnchor, constant: -16),
            hostingController.view.widthAnchor.constraint(equalToConstant: 160),
            hostingController.view.heightAnchor.constraint(equalToConstant: 30)
        ])
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
        
        holdSpeedIndicator.backgroundColor = UIColor(red: 51/255.0, green: 51/255.0, blue: 51/255.0, alpha: 0.8)
        holdSpeedIndicator.tintColor = .white
        holdSpeedIndicator.setTitleColor(.white, for: .normal)
        holdSpeedIndicator.layer.cornerRadius = 21
        holdSpeedIndicator.alpha = 0
        
        holdSpeedIndicator.layer.shadowColor = UIColor.black.cgColor
        holdSpeedIndicator.layer.shadowOffset = CGSize(width: 0, height: 2)
        holdSpeedIndicator.layer.shadowOpacity = 0.6
        holdSpeedIndicator.layer.shadowRadius = 4
        holdSpeedIndicator.layer.masksToBounds = false
        
        view.addSubview(holdSpeedIndicator)
        holdSpeedIndicator.translatesAutoresizingMaskIntoConstraints = false
        
        NSLayoutConstraint.activate([
            holdSpeedIndicator.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            holdSpeedIndicator.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 20),
            holdSpeedIndicator.heightAnchor.constraint(equalToConstant: 40),
            holdSpeedIndicator.widthAnchor.constraint(greaterThanOrEqualToConstant: 85)
        ])
        
        holdSpeedIndicator.isUserInteractionEnabled = false
    }
    
    private func updateSkipButtonsVisibility() {
        let t = currentTimeVal
        let controlsShowing = isControlsVisible
        
        func handle(_ button: UIButton, range: CMTimeRange?) {
            guard let r = range else { button.isHidden = true; return }
            
            let inInterval = t >= r.start.seconds && t <= r.end.seconds
            let target     = controlsShowing ? 0.0 : skipButtonBaseAlpha
            
            if inInterval {
                if button.isHidden {
                    button.alpha = 0
                }
                button.isHidden = false
                
                UIView.animate(withDuration: 0.25) {
                    button.alpha = target
                }
                return
            }
            
            guard !button.isHidden else { return }
            UIView.animate(withDuration: 0.15, animations: {
                button.alpha = 0
            }) { _ in
                button.isHidden = true
            }
        }
        
        handle(skipIntroButton,  range: skipIntervals.op)
        handle(skipOutroButton,  range: skipIntervals.ed)
        
        if skipIntroDismissedInSession {
            skipIntroButton.isHidden = true
        } else {
            handle(skipIntroButton, range: skipIntervals.op)
        }
        if skipOutroDismissedInSession {
            skipOutroButton.isHidden = true
        } else {
            handle(skipOutroButton, range: skipIntervals.ed)
        }
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
                fillColor: .white.opacity(0.6),
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
        skipIntroButton = GradientOverlayButton(type: .system)
        skipIntroButton.setTitle(" Skip Intro", for: .normal)
        skipIntroButton.titleLabel?.font = UIFont.systemFont(ofSize: 14, weight: .bold)
        skipIntroButton.setImage(introImage, for: .normal)
        
        skipIntroButton.backgroundColor = UIColor(red: 51/255.0, green: 51/255.0, blue: 51/255.0, alpha: 0.8)
        skipIntroButton.contentEdgeInsets = UIEdgeInsets(top: 6, left: 10, bottom: 6, right: 10)
        skipIntroButton.tintColor = .white
        skipIntroButton.setTitleColor(.white, for: .normal)
        skipIntroButton.layer.cornerRadius = 21
        skipIntroButton.alpha = skipButtonBaseAlpha
        
        skipIntroButton.layer.shadowColor = UIColor.black.cgColor
        skipIntroButton.layer.shadowOffset = CGSize(width: 0, height: 2)
        skipIntroButton.layer.shadowOpacity = 0.6
        skipIntroButton.layer.shadowRadius = 4
        skipIntroButton.layer.masksToBounds = false
        
        skipIntroButton.addTarget(self, action: #selector(skipIntro), for: .touchUpInside)
        
        view.addSubview(skipIntroButton)
        skipIntroButton.translatesAutoresizingMaskIntoConstraints = false
        
        NSLayoutConstraint.activate([
            skipIntroButton.trailingAnchor.constraint(equalTo: sliderHostingController!.view.trailingAnchor),
            skipIntroButton.bottomAnchor.constraint(equalTo: sliderHostingController!.view.topAnchor, constant: -5),
            skipIntroButton.heightAnchor.constraint(equalToConstant: 40),
            skipIntroButton.widthAnchor.constraint(greaterThanOrEqualToConstant: 104)
        ])
        
        let outroConfig = UIImage.SymbolConfiguration(pointSize: 14, weight: .bold)
        let outroImage = UIImage(systemName: "forward.frame", withConfiguration: outroConfig)
        skipOutroButton = GradientOverlayButton(type: .system)
        skipOutroButton.setTitle(" Skip Outro", for: .normal)
        skipOutroButton.titleLabel?.font = UIFont.systemFont(ofSize: 14, weight: .bold)
        skipOutroButton.setImage(outroImage, for: .normal)
        
        skipOutroButton.backgroundColor = UIColor(red: 51/255.0, green: 51/255.0, blue: 51/255.0, alpha: 0.8)
        skipOutroButton.contentEdgeInsets = UIEdgeInsets(top: 6, left: 10, bottom: 6, right: 10)
        skipOutroButton.tintColor = .white
        skipOutroButton.setTitleColor(.white, for: .normal)
        skipOutroButton.layer.cornerRadius = 21
        skipOutroButton.alpha = skipButtonBaseAlpha
        
        skipOutroButton.layer.shadowColor = UIColor.black.cgColor
        skipOutroButton.layer.shadowOffset = CGSize(width: 0, height: 2)
        skipOutroButton.layer.shadowOpacity = 0.6
        skipOutroButton.layer.shadowRadius = 4
        skipOutroButton.layer.masksToBounds = false
        
        skipOutroButton.addTarget(self, action: #selector(skipOutro), for: .touchUpInside)
        
        view.addSubview(skipOutroButton)
        skipOutroButton.translatesAutoresizingMaskIntoConstraints = false
        
        NSLayoutConstraint.activate([
            skipOutroButton.trailingAnchor.constraint(equalTo: sliderHostingController!.view.trailingAnchor),
            skipOutroButton.bottomAnchor.constraint(equalTo: sliderHostingController!.view.topAnchor, constant: -5),
            skipOutroButton.heightAnchor.constraint(equalToConstant: 40),
            skipOutroButton.widthAnchor.constraint(greaterThanOrEqualToConstant: 104)
        ])
    }
    
    private func setupDimButton() {
        let cfg = UIImage.SymbolConfiguration(pointSize: 24, weight: .regular)
        dimButton = UIButton(type: .system)
        dimButton.setImage(UIImage(systemName: "moon.fill", withConfiguration: cfg), for: .normal)
        dimButton.tintColor = .white
        dimButton.addTarget(self, action: #selector(dimTapped), for: .touchUpInside)
        controlsContainerView.addSubview(dimButton)
        dimButton.translatesAutoresizingMaskIntoConstraints = false
        
        dimButton.layer.shadowColor = UIColor.black.cgColor
        dimButton.layer.shadowOffset = CGSize(width: 0, height: 2)
        dimButton.layer.shadowOpacity = 0.6
        dimButton.layer.shadowRadius = 4
        dimButton.layer.masksToBounds = false
        
        NSLayoutConstraint.activate([
            dimButton.topAnchor.constraint(equalTo: volumeSliderHostingView!.bottomAnchor, constant: 15),
            dimButton.trailingAnchor.constraint(equalTo: volumeSliderHostingView!.trailingAnchor),
            dimButton.widthAnchor.constraint(equalToConstant: 24),
            dimButton.heightAnchor.constraint(equalToConstant: 24)
        ])
        
        dimButtonToSlider = dimButton.trailingAnchor.constraint(equalTo: volumeSliderHostingView!.trailingAnchor)
        dimButtonToRight = dimButton.trailingAnchor.constraint(equalTo: controlsContainerView.trailingAnchor, constant: -16)
        dimButtonToSlider.isActive = true
    }
    
    private func setupLockButton() {
        let cfg = UIImage.SymbolConfiguration(pointSize: 24, weight: .regular)
        lockButton = UIButton(type: .system)
        lockButton.setImage(
            UIImage(systemName: "lock.open.fill", withConfiguration: cfg),
            for: .normal
        )
        lockButton.tintColor = .white
        lockButton.layer.shadowColor   = UIColor.black.cgColor
        lockButton.layer.shadowOffset  = CGSize(width: 0, height: 2)
        lockButton.layer.shadowOpacity = 0.6
        lockButton.layer.shadowRadius  = 4
        lockButton.layer.masksToBounds = false
        
        lockButton.addTarget(self, action: #selector(lockTapped), for: .touchUpInside)
        
        view.addSubview(lockButton)
        lockButton.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            lockButton.topAnchor.constraint(equalTo: volumeSliderHostingView!.bottomAnchor, constant: 60),
            lockButton.trailingAnchor.constraint(equalTo: volumeSliderHostingView!.trailingAnchor),
            lockButton.widthAnchor.constraint(equalToConstant: 24),
            lockButton.heightAnchor.constraint(equalToConstant: 24),
        ])
    }
    
    func updateMarqueeConstraints() {
        UIView.performWithoutAnimation {
            NSLayoutConstraint.deactivate(currentMarqueeConstraints)
            
            let leftSpacing: CGFloat = 2
            let rightSpacing: CGFloat = 6
            let trailingAnchor: NSLayoutXAxisAnchor = (volumeSliderHostingView?.isHidden == false)
            ? volumeSliderHostingView!.leadingAnchor
            : view.safeAreaLayoutGuide.trailingAnchor
            
            currentMarqueeConstraints = [
                marqueeLabel.leadingAnchor.constraint(
                    equalTo: dismissButton.trailingAnchor, constant: leftSpacing),
                marqueeLabel.trailingAnchor.constraint(
                    equalTo: trailingAnchor, constant: -rightSpacing - 10),
                marqueeLabel.centerYAnchor.constraint(equalTo: dismissButton.centerYAnchor)
            ]
            NSLayoutConstraint.activate(currentMarqueeConstraints)
            view.layoutIfNeeded()
        }
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
        controlsContainerView.addSubview(airplayButton)
        
        guard AVPictureInPictureController.isPictureInPictureSupported() else {
            return
        }
        let pipPlayerLayer = AVPlayerLayer(player: playerViewController.player)
        pipPlayerLayer.frame = playerViewController.view.layer.bounds
        pipPlayerLayer.videoGravity = .resizeAspect
        
        playerViewController.view.layer.insertSublayer(pipPlayerLayer, at: 0)
        pipController = AVPictureInPictureController(playerLayer: pipPlayerLayer)
        pipController?.delegate = self
        
        
        let config = UIImage.SymbolConfiguration(pointSize: 15, weight: .medium)
        let Image = UIImage(systemName: "pip", withConfiguration: config)
        pipButton = UIButton(type: .system)
        pipButton.setImage(Image, for: .normal)
        pipButton.tintColor = .white
        pipButton.addTarget(self, action: #selector(pipButtonTapped(_:)), for: .touchUpInside)
        
        pipButton.layer.shadowColor = UIColor.black.cgColor
        pipButton.layer.shadowOffset = CGSize(width: 0, height: 2)
        pipButton.layer.shadowOpacity = 0.6
        pipButton.layer.shadowRadius = 4
        pipButton.layer.masksToBounds = false
        
        controlsContainerView.addSubview(pipButton)
        pipButton.translatesAutoresizingMaskIntoConstraints = false
        
        NSLayoutConstraint.activate([
            pipButton.centerYAnchor.constraint(equalTo: dimButton.centerYAnchor),
            pipButton.trailingAnchor.constraint(equalTo: dimButton.leadingAnchor, constant: -8),
            pipButton.widthAnchor.constraint(equalToConstant: 44),
            pipButton.heightAnchor.constraint(equalToConstant: 44),
            airplayButton.centerYAnchor.constraint(equalTo: pipButton.centerYAnchor),
            airplayButton.trailingAnchor.constraint(equalTo: pipButton.leadingAnchor, constant: -8),
            airplayButton.widthAnchor.constraint(equalToConstant: 44),
            airplayButton.heightAnchor.constraint(equalToConstant: 44)
        ])
        
        pipButton.isHidden = !isPipButtonVisible
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(startPipIfNeeded),
            name: UIApplication.willResignActiveNotification,
            object: nil
        )
    }
    
    
    func setupMenuButton() {
        let config = UIImage.SymbolConfiguration(pointSize: 15, weight: .bold)
        let image = UIImage(systemName: "text.bubble", withConfiguration: config)
        
        menuButton = UIButton(type: .system)
        menuButton.setImage(image, for: .normal)
        menuButton.tintColor = .white
        
        if let subtitlesURL = subtitlesURL, !subtitlesURL.isEmpty {
            menuButton.showsMenuAsPrimaryAction = true
            menuButton.menu = buildOptionsMenu()
        } else {
            menuButton.isHidden = true
        }
        
        dismissButton.layer.shadowColor = UIColor.black.cgColor
        dismissButton.layer.shadowOffset = CGSize(width: 0, height: 2)
        dismissButton.layer.shadowOpacity = 0.6
        dismissButton.layer.shadowRadius = 4
        dismissButton.layer.masksToBounds = false
        
        controlsContainerView.addSubview(menuButton)
        menuButton.translatesAutoresizingMaskIntoConstraints = false
        
        NSLayoutConstraint.activate([
            menuButton.topAnchor.constraint(equalTo: qualityButton.topAnchor),
            menuButton.widthAnchor.constraint(equalToConstant: 40),
            menuButton.heightAnchor.constraint(equalToConstant: 40),
        ])
        
        currentMenuButtonTrailing = menuButton.trailingAnchor.constraint(equalTo: qualityButton.leadingAnchor, constant: -6)
    }
    
    func setupSpeedButton() {
        let config = UIImage.SymbolConfiguration(pointSize: 15, weight: .bold)
        let image = UIImage(systemName: "speedometer", withConfiguration: config)
        
        speedButton = UIButton(type: .system)
        speedButton.setImage(image, for: .normal)
        speedButton.tintColor = .white
        speedButton.showsMenuAsPrimaryAction = true
        speedButton.menu = speedChangerMenu()
        
        speedButton.layer.shadowColor = UIColor.black.cgColor
        speedButton.layer.shadowOffset = CGSize(width: 0, height: 2)
        speedButton.layer.shadowOpacity = 0.6
        speedButton.layer.shadowRadius = 4
        speedButton.layer.masksToBounds = false
        
        controlsContainerView.addSubview(speedButton)
        speedButton.translatesAutoresizingMaskIntoConstraints = false
        
        NSLayoutConstraint.activate([
            speedButton.topAnchor.constraint(equalTo: watchNextButton.topAnchor),
            speedButton.trailingAnchor.constraint(equalTo: watchNextButton.leadingAnchor, constant: 18),
            speedButton.widthAnchor.constraint(equalToConstant: 40),
            speedButton.heightAnchor.constraint(equalToConstant: 40)
        ])
    }
    
    func setupWatchNextButton() {
        let config = UIImage.SymbolConfiguration(pointSize: 15, weight: .bold)
        let image = UIImage(systemName: "forward.end", withConfiguration: config)
        
        watchNextButton = UIButton(type: .system)
        watchNextButton.setImage(image, for: .normal)
        watchNextButton.backgroundColor = .clear
        watchNextButton.tintColor = .white
        watchNextButton.setTitleColor(.white, for: .normal)
        
        // The shadow:
        watchNextButton.layer.shadowColor = UIColor.black.cgColor
        watchNextButton.layer.shadowOffset = CGSize(width: 0, height: 2)
        watchNextButton.layer.shadowOpacity = 0.6
        watchNextButton.layer.shadowRadius = 4
        watchNextButton.layer.masksToBounds = false
        
        watchNextButton.addTarget(self, action: #selector(watchNextTapped), for: .touchUpInside)
        
        controlsContainerView.addSubview(watchNextButton)
        watchNextButton.translatesAutoresizingMaskIntoConstraints = false
        
        NSLayoutConstraint.activate([
            watchNextButton.trailingAnchor.constraint(equalTo: sliderHostingController!.view.trailingAnchor, constant: 20),
            watchNextButton.bottomAnchor.constraint(equalTo: sliderHostingController!.view.topAnchor, constant: -5),
            watchNextButton.heightAnchor.constraint(equalToConstant: 40),
            watchNextButton.widthAnchor.constraint(equalToConstant: 80)
        ])
    }
    
    func setupSkip85Button() {
        let config = UIImage.SymbolConfiguration(pointSize: 14, weight: .bold)
        let image = UIImage(systemName: "goforward", withConfiguration: config)
        
        skip85Button = GradientOverlayButton(type: .system)
        skip85Button.setTitle(" Skip 85s", for: .normal)
        skip85Button.titleLabel?.font = UIFont.systemFont(ofSize: 14, weight: .bold)
        skip85Button.setImage(image, for: .normal)
        
        skip85Button.backgroundColor = UIColor(red: 51/255.0, green: 51/255.0, blue: 51/255.0, alpha: 0.8)
        skip85Button.contentEdgeInsets = UIEdgeInsets(top: 6, left: 10, bottom: 6, right: 10)
        skip85Button.tintColor = .white
        skip85Button.setTitleColor(.white, for: .normal)
        skip85Button.layer.cornerRadius = 21
        skip85Button.alpha = 0.7
        
        skip85Button.layer.shadowColor = UIColor.black.cgColor
        skip85Button.layer.shadowOffset = CGSize(width: 0, height: 2)
        skip85Button.layer.shadowOpacity = 0.6
        skip85Button.layer.shadowRadius = 4
        skip85Button.layer.masksToBounds = false
        
        skip85Button.addTarget(self, action: #selector(skip85Tapped), for: .touchUpInside)
        
        view.addSubview(skip85Button)
        skip85Button.translatesAutoresizingMaskIntoConstraints = false
        
        NSLayoutConstraint.activate([
            skip85Button.leadingAnchor.constraint(equalTo: sliderHostingController!.view.leadingAnchor),
            skip85Button.bottomAnchor.constraint(equalTo: sliderHostingController!.view.topAnchor, constant: -5),
            skip85Button.heightAnchor.constraint(equalToConstant: 40),
            skip85Button.widthAnchor.constraint(greaterThanOrEqualToConstant: 97)
        ])
        
        skip85Button.isHidden = !isSkip85Visible
    }
    
    
    private func setupQualityButton() {
        let config = UIImage.SymbolConfiguration(pointSize: 15, weight: .bold)
        let image = UIImage(systemName: "4k.tv", withConfiguration: config)
        
        qualityButton = UIButton(type: .system)
        qualityButton.setImage(image, for: .normal)
        qualityButton.tintColor = .white
        qualityButton.showsMenuAsPrimaryAction = true
        qualityButton.menu = qualitySelectionMenu()
        qualityButton.isHidden = true
        
        qualityButton.layer.shadowColor = UIColor.black.cgColor
        qualityButton.layer.shadowOffset = CGSize(width: 0, height: 2)
        qualityButton.layer.shadowOpacity = 0.6
        qualityButton.layer.shadowRadius = 4
        qualityButton.layer.masksToBounds = false
        
        controlsContainerView.addSubview(qualityButton)
        qualityButton.translatesAutoresizingMaskIntoConstraints = false
        
        NSLayoutConstraint.activate([
            qualityButton.topAnchor.constraint(equalTo: speedButton.topAnchor),
            qualityButton.trailingAnchor.constraint(equalTo: speedButton.leadingAnchor, constant: -6),
            qualityButton.widthAnchor.constraint(equalToConstant: 40),
            qualityButton.heightAnchor.constraint(equalToConstant: 40)
        ])
    }
    
    func setupAudioMenuButton() {
        let config = UIImage.SymbolConfiguration(pointSize: 15, weight: .bold)
        let image = UIImage(systemName: "waveform.circle", withConfiguration: config)
        
        audioTrackButton = UIButton(type: .system)
        audioTrackButton.setImage(image, for: .normal)
        audioTrackButton.tintColor = .white
        audioTrackButton.showsMenuAsPrimaryAction = true
        audioTrackButton.menu = audioTrackSelectionMenu()
        audioTrackButton.isHidden = true
        
        audioTrackButton.layer.shadowColor = UIColor.black.cgColor
        audioTrackButton.layer.shadowOffset = CGSize(width: 0, height: 2)
        audioTrackButton.layer.shadowOpacity = 0.6
        audioTrackButton.layer.shadowRadius = 4
        audioTrackButton.layer.masksToBounds = false
        
        controlsContainerView.addSubview(audioTrackButton)
        audioTrackButton.translatesAutoresizingMaskIntoConstraints = false
        
        NSLayoutConstraint.activate([
            audioTrackButton.topAnchor.constraint(equalTo: qualityButton.topAnchor),
            audioTrackButton.trailingAnchor.constraint(equalTo: qualityButton.leadingAnchor, constant: -6),
            audioTrackButton.widthAnchor.constraint(equalToConstant: 40),
            audioTrackButton.heightAnchor.constraint(equalToConstant: 40)
        ])
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
        timeObserverToken = player.addPeriodicTimeObserver(forInterval: interval,
                                                           queue: .main)
        { [weak self] time in
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
            
            DispatchQueue.main.async {
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
                
                if remainingPercentage < 0.1 &&
                    self.aniListID != 0 &&
                    !self.aniListUpdatedSuccessfully &&
                    !self.aniListUpdateImpossible
                {
                    self.tryAniListUpdate()
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
                    fillColor: .white.opacity(0.6),
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
    
    func updateMenuButtonConstraints() {
        currentMenuButtonTrailing.isActive = false
        
        let anchor: NSLayoutXAxisAnchor
        if (!qualityButton.isHidden) {
            anchor = qualityButton.leadingAnchor
        } else if (!speedButton.isHidden) {
            anchor = speedButton.leadingAnchor
        } else {
            anchor = controlsContainerView.trailingAnchor
        }
        
        currentMenuButtonTrailing = menuButton.trailingAnchor.constraint(equalTo: anchor, constant: -6)
        currentMenuButtonTrailing.isActive = true
    }
    
    @objc func toggleControls() {
        if controlsLocked {
            lockButton.alpha = 1.0
            lockButtonTimer?.invalidate()
            lockButtonTimer = Timer.scheduledTimer(
                withTimeInterval: 3.0,
                repeats: false
            ) { [weak self] _ in
                UIView.animate(withDuration: 0.3) {
                    self?.lockButton.alpha = 0
                }
            }
            updateSkipButtonsVisibility()
            return
        }
        
        if isDimmed {
            dimButton.isHidden = false
            dimButton.alpha = 1.0
            dimButtonTimer?.invalidate()
            dimButtonTimer = Timer.scheduledTimer(withTimeInterval: 3.0, repeats: false) { [weak self] _ in
                UIView.animate(withDuration: 0.3) {
                    self?.dimButton.alpha = 0
                }
            }
            
            updateSkipButtonsVisibility()
            return
        }
        
        isControlsVisible.toggle()
        UIView.animate(withDuration: 0.2) {
            let alpha: CGFloat = self.isControlsVisible ? 1.0 : 0.0
            self.controlsContainerView.alpha = alpha
            self.skip85Button.alpha = alpha
            self.lockButton.alpha = alpha
            self.subtitleBottomToSafeAreaConstraint?.isActive = !self.isControlsVisible
            self.subtitleBottomToSliderConstraint?.isActive = self.isControlsVisible
            self.view.layoutIfNeeded()
        }
        updateSkipButtonsVisibility()
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
            guard self != nil else { return }        }
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
            
            DispatchQueue.main.async {
                if !self.isControlsVisible {
                    self.isControlsVisible = true
                    UIView.animate(withDuration: 0.1, animations: {
                        self.controlsContainerView.alpha = 1.0
                        self.skip85Button.alpha = 0.8
                    })
                    self.updateSkipButtonsVisibility()
                }
            }
        } else {
            player.play()
            player.rate = currentPlaybackSpeed
            isPlaying = true
            playPauseButton.image = UIImage(systemName: "pause.fill")
        }
    }
    
    @objc private func pipButtonTapped(_ sender: UIButton) {
        guard let pip = pipController else { return }
        if pip.isPictureInPictureActive {
            pip.stopPictureInPicture()
        } else {
            pip.startPictureInPicture()
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
        
        if controlsLocked {
            UIView.animate(withDuration: 0.25) {
                self.controlsContainerView.alpha = 0
                self.dimButton.alpha             = 0
                for v in self.controlsToHide { v.alpha = 0 }
                self.skipIntroButton.alpha = 0
                self.skipOutroButton.alpha = 0
                self.skip85Button.alpha    = 0
                self.lockButton.alpha = 0
                
                self.subtitleBottomToSafeAreaConstraint?.isActive = true
                self.subtitleBottomToSliderConstraint?.isActive    = false
                
                self.view.layoutIfNeeded()
            }
            
            lockButton.setImage(UIImage(systemName: "lock.fill"), for: .normal)
            
        } else {
            UIView.animate(withDuration: 0.25) {
                self.controlsContainerView.alpha = 1
                self.dimButton.alpha             = 1
                for v in self.controlsToHide { v.alpha = 1 }
                
                self.subtitleBottomToSafeAreaConstraint?.isActive = false
                self.subtitleBottomToSliderConstraint?.isActive    = true
                
                self.view.layoutIfNeeded()
            }
            
            lockButton.setImage(UIImage(systemName: "lock.open.fill"), for: .normal)
            updateSkipButtonsVisibility()
        }
    }
    
    @objc private func skipIntro() {
        if let range = skipIntervals.op {
            player.seek(to: range.end)
            skipIntroButton.isHidden = true
        }
    }
    
    @objc private func skipOutro() {
        if let range = skipIntervals.ed {
            player.seek(to: range.end)
            skipOutroButton.isHidden = true
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
    
    @objc private func handleHoldForPause(_ gesture: UILongPressGestureRecognizer) {
        guard isHoldPauseEnabled else { return }
        
        if gesture.state == .began {
            togglePlayPause()
        }
    }
    
    @objc private func dimTapped() {
        isDimmed.toggle()
        isControlsVisible = !isDimmed
        dimButtonTimer?.invalidate()
        
        UIView.animate(withDuration: 0.25) {
            self.blackCoverView.alpha = self.isDimmed ? 1.0 : 0.4
            for v in self.controlsToHide { v.alpha = self.isDimmed ? 0 :  1 }
            self.dimButton.alpha  = self.isDimmed ? 0 : 1
            self.lockButton.alpha = self.isDimmed ? 0 : 1
            
            self.subtitleBottomToSafeAreaConstraint?.isActive = !self.isControlsVisible
            self.subtitleBottomToSliderConstraint?.isActive    =  self.isControlsVisible
            
            self.view.layoutIfNeeded()
        }
        
        dimButtonToSlider.isActive = !isDimmed
        dimButtonToRight.isActive  =  isDimmed
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
            guard let self = self,
                  let data = data,
                  let content = String(data: data, encoding: .utf8) else {
                      Logger.shared.log("Failed to load m3u8 file")
                      DispatchQueue.main.async {
                          self?.qualities = []
                          completion()
                      }
                      return
                  }
            
            let lines = content.components(separatedBy: .newlines)
            var qualities: [(String, String)] = []
            var audioTracks: [(name: String, groupID: String, uri: String)] = []
            
            func getQualityName(from line: String, url: String) -> String? {
                if let resRange = line.range(of: "RESOLUTION=") {
                    let afterRes = line[resRange.upperBound...]
                    let resString = afterRes.split(separator: ",").first ?? ""
                    if let heightStr = resString.split(separator: "x").last,
                       let height = Int(heightStr) {
                        switch height {
                        case 1080...: return "\(height)p (FHD)"
                        case 720..<1080: return "\(height)p (HD)"
                        case 480..<720: return "\(height)p (SD)"
                        default: return "\(height)p"
                        }
                    }
                }
                if let match = url.range(of: "rendition=([0-9]+p)", options: .regularExpression) {
                    let rendition = String(url[match]).replacingOccurrences(of: "rendition=", with: "")
                    return rendition
                }
                return nil
            }
            
            for (index, line) in lines.enumerated() {
                if line.hasPrefix("#EXT-X-MEDIA:") && line.contains("TYPE=AUDIO") {
                    let name = line.components(separatedBy: "NAME=\"").last?.components(separatedBy: "\"").first ?? "Unknown"
                    let groupID = line.components(separatedBy: "GROUP-ID=\"").last?.components(separatedBy: "\"").first ?? ""
                    let uri = line.components(separatedBy: "URI=\"").last?.components(separatedBy: "\"").first ?? ""
                    audioTracks.append((name: name, groupID: groupID, uri: uri))
                }
                if line.contains("#EXT-X-STREAM-INF"), index + 1 < lines.count {
                    let nextLine = lines[index + 1].trimmingCharacters(in: .whitespacesAndNewlines)
                    let qualityName = getQualityName(from: line, url: nextLine) ?? "Unknown"
                    var qualityURL = nextLine
                    if !nextLine.hasPrefix("http") {
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
            
            DispatchQueue.main.async {
                let sortedQualities = qualities.sorted { first, second in
                    let firstHeight = Int(first.0.components(separatedBy: CharacterSet.decimalDigits.inverted).joined()) ?? 0
                    let secondHeight = Int(second.0.components(separatedBy: CharacterSet.decimalDigits.inverted).joined()) ?? 0
                    return firstHeight > secondHeight
                }
                self.qualities = sortedQualities
                self.audioTracks = audioTracks
                self.audioTrackButton.isHidden = self.audioTracks.isEmpty
                self.audioTrackButton.menu = self.audioTrackSelectionMenu()
                completion()
            }
        }.resume()
    }
    
    private func audioTrackSelectionMenu() -> UIMenu {
        var menuItems: [UIMenuElement] = []
        if audioTracks.isEmpty {
            let unavailable = UIAction(title: "No alternate audio", attributes: .disabled) { _ in }
            menuItems.append(unavailable)
        } else {
            for (name, _, _) in audioTracks {
                let action = UIAction(title: name, state: (lastSelectedAudioTrack == name ? .on : .off)) { [weak self] _ in
                    self?.switchToAudioTrack(named: name)
                }
                menuItems.append(action)
            }
        }
        return UIMenu(title: "Audio Track", children: menuItems)
    }
    
    private func switchToAudioTrack(named name: String) {
        lastSelectedAudioTrack = name
        guard let playerItem = player.currentItem else { return }
        guard let group = playerItem.asset.mediaSelectionGroup(forMediaCharacteristic: .audible) else { return }
        guard let option = group.options.first(where: { $0.displayName == name }) else { return }
        playerItem.select(option, in: group)
        audioTrackButton.menu = audioTrackSelectionMenu()
    }
    
    private func switchToQuality(urlString: String) {
        guard let url = URL(string: urlString),
              currentQualityURL?.absoluteString != urlString else { return }
        
        let currentTime = player.currentTime()
        let wasPlaying = player.rate > 0
        let audioTrackToApply = lastSelectedAudioTrack
        
        player.pause()
        
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
        
        asset.loadValuesAsynchronously(forKeys: ["playable"]) { [weak self] in
            DispatchQueue.main.async {
                guard let self = self else { return }
                let observer = playerItem.observe(\.status, options: [.new]) { [weak self] item, _ in
                    guard let self = self else { return }
                    
                    if item.status == .readyToPlay {
                        if let audioTrackName = audioTrackToApply,
                           let group = item.asset.mediaSelectionGroup(forMediaCharacteristic: .audible),
                           let option = group.options.first(where: { $0.displayName == audioTrackName }) {
                            item.select(option, in: group)
                        }
                        
                        self.player.seek(to: currentTime)
                        if wasPlaying {
                            self.player.play()
                        }
                    }
                }
                self.player.replaceCurrentItem(with: playerItem)
                
                self.currentQualityURL = url
                UserDefaults.standard.set(urlString, forKey: "lastSelectedQuality")
                self.qualityButton.menu = self.qualitySelectionMenu()
                
                if let selectedQuality = self.qualities.first(where: { $0.1 == urlString })?.0 {
                    DropManager.shared.showDrop(title: "Quality: \(selectedQuality)", subtitle: "", duration: 0.5, icon: UIImage(systemName: "eye"))
                }
                
                DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                    observer.invalidate()
                }
            }
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
        let streamType = module.metadata.streamType.lowercased()
        
        if url.absoluteString.contains(".m3u8") || url.absoluteString.contains(".m3u") || streamType.contains("hls") {
            isHLSStream = true
            baseM3U8URL = url
            currentQualityURL = url
            
            parseM3U8(url: url) { [weak self] in
                guard let self = self else { return }
                if let last = UserDefaults.standard.string(forKey: "lastSelectedQuality"),
                   self.qualities.contains(where: { $0.1 == last }) {
                    self.switchToQuality(urlString: last)
                }
                
                self.qualityButton.isHidden = false
                self.qualityButton.menu = self.qualitySelectionMenu()
                self.updateMenuButtonConstraints()
                UIView.animate(withDuration: 0.25, delay: 0, options: .curveEaseInOut) {
                    self.view.layoutIfNeeded()
                }
            }
        } else {
            isHLSStream = false
            qualityButton.isHidden = true
            updateMenuButtonConstraints()
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
            self.holdSpeedIndicator.alpha = 0.8
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
                fillColor: .white.opacity(0.6),
                emptyColor: .white.opacity(0.3),
                height: 10,
                onEditingChanged: { _ in }
            )
                .shadow(color: Color.black.opacity(0.6), radius: 4, x: 0, y: 2)
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

// yes? Like the plural of the famous american rapper ye? -IBHRAD
// low taper fade the meme is massive -cranci
// The mind is the source of good and evil, only you yourself can decide which you will bring yourself. -seiike
// guys watch Clannad already - ibro
// May the Divine Providence bestow its infinite mercy upon your soul, and may eternal grace find you beyond the shadows of this mortal realm. - paul, 15/11/2005 - 13/05/2023
// this dumbass ↑ defo used gpt, ong he did bro
