//
//  CustomPlayer.swift
//  test2
//
//  Created by Francesco on 23/02/25.
//

import UIKit
import MarqueeLabel
import AVKit
import SwiftUI
import AVFoundation
import MediaPlayer

// MARK: - SliderViewModel

class SliderViewModel: ObservableObject {
    @Published var sliderValue: Double = 0.0
    @Published var bufferValue: Double = 0.0
}

// MARK: - CustomMediaPlayerViewController

class CustomMediaPlayerViewController: UIViewController {
    let module: ScrapingModule
    let streamURL: String
    let fullUrl: String
    let titleText: String
    let episodeNumber: Int
    let episodeImageUrl: String
    let subtitlesURL: String?
    let onWatchNext: () -> Void
    let aniListID: Int
    
    private var aniListUpdatedSuccessfully = false
    private var aniListUpdateImpossible: Bool = false
    private var aniListRetryCount = 0
    private let aniListMaxRetries = 6
    
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
            return true
        }
        return UserDefaults.standard.bool(forKey: "doubleTapSeekEnabled")
    }
    
    var showWatchNextButton = true
    var watchNextButtonTimer: Timer?
    var isWatchNextRepositioned: Bool = false
    var isWatchNextVisible: Bool = false
    var lastDuration: Double = 0.0
    var watchNextButtonAppearedAt: Double?
    
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
    var subtitlesEnabled: Bool = true {
        didSet {
            subtitleLabel.isHidden = !subtitlesEnabled
        }
    }
    
    var marqueeLabel: MarqueeLabel!
    var playerViewController: AVPlayerViewController!
    var controlsContainerView: UIView!
    var playPauseButton: UIImageView!
    var backwardButton: UIImageView!
    var forwardButton: UIImageView!
    var subtitleLabel: UILabel!
    var dismissButton: UIButton!
    var menuButton: UIButton!
    var watchNextButton: UIButton!
    var watchNextIconButton: UIButton!
    var blackCoverView: UIView!
    var speedButton: UIButton!
    var skip85Button: UIButton!
    var qualityButton: UIButton!
    
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
    
    var subtitleBottomConstraint: NSLayoutConstraint?
    var subtitleBottomPadding: CGFloat = 10.0 {
        didSet {
            updateSubtitleLabelConstraints()
        }
    }
    
    private var playerItemKVOContext = 0
    private var loadedTimeRangesObservation: NSKeyValueObservation?
    private var playerTimeControlStatusObserver: NSKeyValueObservation?
    
    private var volumeObserver: NSKeyValueObservation?
    private var audioSession = AVAudioSession.sharedInstance()
    private var hiddenVolumeView = MPVolumeView(frame: .zero)
    private var systemVolumeSlider: UISlider?
    private var volumeValue: Double = 0.0
    private var volumeViewModel = VolumeViewModel()
    var volumeSliderHostingView: UIView?
    
    init(module: ScrapingModule,
         urlString: String,
         fullUrl: String,
         title: String,
         episodeNumber: Int,
         onWatchNext: @escaping () -> Void,
         subtitlesURL: String?,
         aniListID: Int,
         episodeImageUrl: String) {
        
        self.module = module
        self.streamURL = urlString
        self.fullUrl = fullUrl
        self.titleText = title
        self.episodeNumber = episodeNumber
        self.episodeImageUrl = episodeImageUrl
        self.onWatchNext = onWatchNext
        self.subtitlesURL = subtitlesURL
        self.aniListID = aniListID
        
        super.init(nibName: nil, bundle: nil)
        
        guard let url = URL(string: urlString) else {
            fatalError("Invalid URL string")
        }
        
        var request = URLRequest(url: url)
        request.addValue("\(module.metadata.baseUrl)", forHTTPHeaderField: "Referer")
        request.addValue("\(module.metadata.baseUrl)", forHTTPHeaderField: "Origin")
        request.addValue("Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/134.0.0.0 Safari/537.36",
                         forHTTPHeaderField: "User-Agent")
        
        let asset = AVURLAsset(url: url, options: ["AVURLAssetHTTPHeaderFieldsKey": request.allHTTPHeaderFields ?? [:]])
        let playerItem = AVPlayerItem(asset: asset)
        self.player = AVPlayer(playerItem: playerItem)
        
        let lastPlayedTime = UserDefaults.standard.double(forKey: "lastPlayedTime_\(fullUrl)")
        if lastPlayedTime > 0 {
            let seekTime = CMTime(seconds: lastPlayedTime, preferredTimescale: 1)
            self.player.seek(to: seekTime) { [weak self] _ in
                self?.updateBufferValue()
            }
        }
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black
        
        setupHoldGesture()
        setInitialPlayerRate()
        loadSubtitleSettings()
        setupPlayerViewController()
        setupControls()
        setupSkipAndDismissGestures()
        addInvisibleControlOverlays()
        setupWatchNextButton()
        setupSubtitleLabel()
        setupDismissButton()
        volumeSlider()
        setupSpeedButton()
        setupQualityButton()
        setupMenuButton()
        setupMarqueeLabel()
        setupSkip85Button()
        addTimeObserver()
        startUpdateTimer()
        setupAudioSession()
        
        if let item = player.currentItem {
            loadedTimeRangesObservation = item.observe(\.loadedTimeRanges, options: [.new, .initial]) { [weak self] (playerItem, change) in
                self?.updateBufferValue()
            }
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            self?.checkForHLSStream()
        }
        
        if isHoldPauseEnabled {
            holdForPause()
        }
        
        do {
            try audioSession.setActive(true)
        } catch {
            print("Error activating audio session: \(error)")
        }
        
        volumeViewModel.value = Double(audioSession.outputVolume)
        
        
        volumeObserver = audioSession.observe(\.outputVolume, options: [.new]) { [weak self] session, change in
            guard let newVol = change.newValue else { return }
            DispatchQueue.main.async {
                self?.volumeViewModel.value = Double(newVol)
                Logger.shared.log("Hardware volume changed, new value: \(newVol)", type: "Debug")
            }
        }
        
        
        if #available(iOS 16.0, *) {
            playerViewController.allowsVideoFrameAnalysis = false
        }
        
        player.play()
        
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
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(playerItemDidChange),
                                               name: .AVPlayerItemNewAccessLogEntry,
                                               object: nil)
        
        skip85Button?.isHidden = !isSkip85Visible
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        
        loadedTimeRangesObservation?.invalidate()
        loadedTimeRangesObservation = nil
        
        if let token = timeObserverToken {
            player.removeTimeObserver(token)
            timeObserverToken = nil
        }
        
        updateTimer?.invalidate()
        inactivityTimer?.invalidate()
        
        player.pause()
        
        if let playbackSpeed = player?.rate {
            UserDefaults.standard.set(playbackSpeed, forKey: "lastPlaybackSpeed")
        }
        
    }
    
    override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?) {
        guard context == &playerItemKVOContext else {
            super.observeValue(forKeyPath: keyPath, of: object, change: change, context: context)
            return
        }
        
        if keyPath == "loadedTimeRanges" {
            updateBufferValue()
        }
    }
    
    private func updateBufferValue() {
        guard let item = player.currentItem else { return }
        
        if let timeRange = item.loadedTimeRanges.first?.timeRangeValue {
            let buffered = CMTimeGetSeconds(timeRange.start) + CMTimeGetSeconds(timeRange.duration)
            DispatchQueue.main.async {
                self.sliderViewModel.bufferValue = buffered
            }
        }
    }
    
    @objc private func playerItemDidChange() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            if self.qualityButton.isHidden && self.isHLSStream {
                self.qualityButton.isHidden = false
                self.qualityButton.menu = self.qualitySelectionMenu()
            }
        }
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
                } else {
                    let wasPlaying = self.isPlaying
                    let targetTime = CMTime(seconds: self.sliderViewModel.sliderValue,
                                            preferredTimescale: 600)
                    self.player.seek(to: targetTime) { [weak self] finished in
                        guard let self = self else { return }
                        
                        let final = self.player.currentTime().seconds
                        self.sliderViewModel.sliderValue = final
                        self.currentTimeVal = final
                        self.updateBufferValue()
                        self.isSliderEditing = false
                        
                        if wasPlaying {
                            self.player.play()
                        }
                    }
                }
            }
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
        subtitleLabel = UILabel()
        subtitleLabel.textAlignment = .center
        subtitleLabel.numberOfLines = 0
        subtitleLabel.font = UIFont.systemFont(ofSize: CGFloat(subtitleFontSize))
        updateSubtitleLabelAppearance()
        view.addSubview(subtitleLabel)
        subtitleLabel.translatesAutoresizingMaskIntoConstraints = false
        
        subtitleBottomConstraint = subtitleLabel.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -subtitleBottomPadding)
        
        NSLayoutConstraint.activate([
            subtitleLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            subtitleBottomConstraint!,
            subtitleLabel.leadingAnchor.constraint(greaterThanOrEqualTo: view.leadingAnchor, constant: 36),
            subtitleLabel.trailingAnchor.constraint(lessThanOrEqualTo: view.trailingAnchor, constant: -36)
        ])
    }
    
    func updateSubtitleLabelConstraints() {
        subtitleBottomConstraint?.constant = -subtitleBottomPadding
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
        
        marqueeLabel.speed = .rate(35)         // Adjust scrolling speed as needed
        marqueeLabel.fadeLength = 10.0         // Fading at the label’s edges
        marqueeLabel.leadingBuffer = 1.0      // Left inset for scrolling
        marqueeLabel.trailingBuffer = 16.0     // Right inset for scrolling
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
        
        // 1. Portrait mode with button visible
        portraitButtonVisibleConstraints = [
            marqueeLabel.leadingAnchor.constraint(equalTo: dismissButton.trailingAnchor, constant: 8),
            marqueeLabel.trailingAnchor.constraint(equalTo: menuButton.leadingAnchor, constant: -16),
            marqueeLabel.centerYAnchor.constraint(equalTo: dismissButton.centerYAnchor)
        ]
        
        // 2. Portrait mode with button hidden
        portraitButtonHiddenConstraints = [
            marqueeLabel.leadingAnchor.constraint(equalTo: dismissButton.trailingAnchor, constant: 12),
            marqueeLabel.trailingAnchor.constraint(equalTo: controlsContainerView.trailingAnchor, constant: -16),
            marqueeLabel.centerYAnchor.constraint(equalTo: dismissButton.centerYAnchor)
        ]
        
        // 3. Landscape mode with button visible (using smaller margins)
        landscapeButtonVisibleConstraints = [
            marqueeLabel.leadingAnchor.constraint(equalTo: dismissButton.trailingAnchor, constant: 8),
            marqueeLabel.trailingAnchor.constraint(equalTo: menuButton.leadingAnchor, constant: -8),
            marqueeLabel.centerYAnchor.constraint(equalTo: dismissButton.centerYAnchor)
        ]
        
        // 4. Landscape mode with button hidden
        landscapeButtonHiddenConstraints = [
            marqueeLabel.leadingAnchor.constraint(equalTo: dismissButton.trailingAnchor, constant: 8),
            marqueeLabel.trailingAnchor.constraint(equalTo: controlsContainerView.trailingAnchor, constant: -8),
            marqueeLabel.centerYAnchor.constraint(equalTo: dismissButton.centerYAnchor)
        ]
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
    
    
    func updateMarqueeConstraints() {
        NSLayoutConstraint.deactivate(currentMarqueeConstraints)
        
        let leftSpacing: CGFloat = 2
        let rightSpacing: CGFloat = 6
        
        let trailingAnchor: NSLayoutXAxisAnchor
        if let volumeView = volumeSliderHostingView, !volumeView.isHidden {
            trailingAnchor = volumeView.leadingAnchor
        } else {
            trailingAnchor = view.safeAreaLayoutGuide.trailingAnchor
        }
        
        currentMarqueeConstraints = [
            marqueeLabel.leadingAnchor.constraint(equalTo: dismissButton.trailingAnchor, constant: leftSpacing),
            marqueeLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -rightSpacing - 10),
            marqueeLabel.centerYAnchor.constraint(equalTo: dismissButton.centerYAnchor)
        ]
        
        NSLayoutConstraint.activate(currentMarqueeConstraints)
        view.layoutIfNeeded()
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
            menuButton.trailingAnchor.constraint(equalTo: qualityButton.leadingAnchor, constant: -6),
            menuButton.widthAnchor.constraint(equalToConstant: 40),
            menuButton.heightAnchor.constraint(equalToConstant: 40)
        ])
    }
    
    func setupSpeedButton() {
        let config = UIImage.SymbolConfiguration(pointSize: 15, weight: .bold)
        let image = UIImage(systemName: "speedometer", withConfiguration: config)
        
        speedButton = UIButton(type: .system)
        speedButton.setImage(image, for: .normal)
        speedButton.tintColor = .white
        speedButton.showsMenuAsPrimaryAction = true
        speedButton.menu = speedChangerMenu()
        
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
        
        skip85Button = UIButton(type: .system)
        skip85Button.setTitle(" Skip 85s", for: .normal)
        skip85Button.titleLabel?.font = UIFont.systemFont(ofSize: 14, weight: .bold)
        skip85Button.setImage(image, for: .normal)
        
        skip85Button.backgroundColor = UIColor(red: 51/255.0, green: 51/255.0, blue: 51/255.0, alpha: 0.8)
        skip85Button.tintColor = .white
        skip85Button.setTitleColor(.white, for: .normal)
        skip85Button.layer.cornerRadius = 21
        skip85Button.alpha = 0.7
        
        skip85Button.contentEdgeInsets = UIEdgeInsets(top: 6, left: 10, bottom: 6, right: 10)
        
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
        
        speedButton.layer.shadowColor = UIColor.black.cgColor
        speedButton.layer.shadowOffset = CGSize(width: 0, height: 2)
        speedButton.layer.shadowOpacity = 0.6
        speedButton.layer.shadowRadius = 4
        speedButton.layer.masksToBounds = false
        
        controlsContainerView.addSubview(qualityButton)
        qualityButton.translatesAutoresizingMaskIntoConstraints = false
        
        NSLayoutConstraint.activate([
            qualityButton.topAnchor.constraint(equalTo: speedButton.topAnchor),
            qualityButton.trailingAnchor.constraint(equalTo: speedButton.leadingAnchor, constant: -6),
            qualityButton.widthAnchor.constraint(equalToConstant: 40),
            qualityButton.heightAnchor.constraint(equalToConstant: 40)
        ])
    }
    
    func updateSubtitleLabelAppearance() {
        subtitleLabel.font = UIFont.systemFont(ofSize: CGFloat(subtitleFontSize))
        subtitleLabel.textColor = subtitleUIColor()
        subtitleLabel.backgroundColor = subtitleBackgroundEnabled ? UIColor.black.withAlphaComponent(0.6) : .clear
        subtitleLabel.layer.cornerRadius = 5
        subtitleLabel.clipsToBounds = true
        subtitleLabel.layer.shadowColor = UIColor.black.cgColor
        subtitleLabel.layer.shadowRadius = CGFloat(subtitleShadowRadius)
        subtitleLabel.layer.shadowOpacity = 1.0
        subtitleLabel.layer.shadowOffset = CGSize.zero
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
    
    func addTimeObserver() {
        let interval = CMTime(seconds: 1.0, preferredTimescale: CMTimeScale(NSEC_PER_SEC))
        timeObserverToken = player.addPeriodicTimeObserver(forInterval: interval,
                                                           queue: .main)
        { [weak self] time in
            guard let self = self,
                  let currentItem = self.player.currentItem,
                  currentItem.duration.seconds.isFinite else { return }
            
            self.updateBufferValue()
            let currentDuration = currentItem.duration.seconds
            if currentDuration.isNaN || currentDuration <= 0 { return }
            
            self.currentTimeVal = time.seconds
            self.duration = currentDuration
            
            if !self.isSliderEditing {
                self.sliderViewModel.sliderValue = max(0, min(self.currentTimeVal, self.duration))
            }
            
            UserDefaults.standard.set(self.currentTimeVal, forKey: "lastPlayedTime_\(self.fullUrl)")
            UserDefaults.standard.set(self.duration, forKey: "totalTime_\(self.fullUrl)")
            
            if self.subtitlesEnabled,
               let currentCue = self.subtitlesLoader.cues.first(where: { self.currentTimeVal >= $0.startTime && self.currentTimeVal <= $0.endTime }) {
                self.subtitleLabel.text = currentCue.text.strippedHTML
            } else {
                self.subtitleLabel.text = ""
            }
            
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
                        module: self.module
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
                        if !editing {
                            let targetTime = CMTime(
                                seconds: self.sliderViewModel.sliderValue,
                                preferredTimescale: 600
                            )
                            self.player.seek(to: targetTime) { [weak self] finished in
                                self?.updateBufferValue()
                            }
                        }
                    }
                )
            }
            
            let isNearEnd = (self.duration - self.currentTimeVal) <= (self.duration * 0.10)
            && self.currentTimeVal != self.duration
            && self.showWatchNextButton
            && self.duration != 0
            
            
            if isNearEnd {
                if !self.isWatchNextVisible {
                    self.watchNextButtonAppearedAt = self.currentTimeVal
                    
                }
            } else {
                
            }
        }
    }
    
    func repositionWatchNextButton() {
        self.isWatchNextRepositioned = true
        UIView.animate(withDuration: 0.3, animations: {
            NSLayoutConstraint.deactivate(self.watchNextButtonNormalConstraints)
            NSLayoutConstraint.activate(self.watchNextButtonControlsConstraints)
            self.view.layoutIfNeeded()
            self.watchNextButton.alpha = 0.0
        }, completion: { _ in
            self.watchNextButton.isHidden = true
        })
        self.watchNextButtonTimer?.invalidate()
        self.watchNextButtonTimer = nil
    }
    
    func startUpdateTimer() {
        updateTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            self.currentTimeVal = self.player.currentTime().seconds
        }
    }
    
    @objc func toggleControls() {
        isControlsVisible.toggle()
        UIView.animate(withDuration: 0.3, delay: 0, options: .curveEaseInOut, animations: {
            let alphaVal: CGFloat = self.isControlsVisible ? 1 : 0
            self.controlsContainerView.alpha = alphaVal
            self.skip85Button.alpha = alphaVal
            self.watchNextButton.alpha = alphaVal
        })
    }
    
    @objc func seekBackwardLongPress(_ gesture: UILongPressGestureRecognizer) {
        if gesture.state == .began {
            let holdValue = UserDefaults.standard.double(forKey: "skipIncrementHold")
            let finalSkip = holdValue > 0 ? holdValue : 30
            currentTimeVal = max(currentTimeVal - finalSkip, 0)
            player.seek(to: CMTime(seconds: currentTimeVal, preferredTimescale: 600)) { [weak self] finished in
                guard let self = self else { return }
                self.updateBufferValue()
            }
        }
    }
    
    @objc func seekForwardLongPress(_ gesture: UILongPressGestureRecognizer) {
        if gesture.state == .began {
            let holdValue = UserDefaults.standard.double(forKey: "skipIncrementHold")
            let finalSkip = holdValue > 0 ? holdValue : 30
            currentTimeVal = min(currentTimeVal + finalSkip, duration)
            player.seek(to: CMTime(seconds: currentTimeVal, preferredTimescale: 600)) { [weak self] finished in
                guard let self = self else { return }
                self.updateBufferValue()
            }
        }
    }
    
    @objc func seekBackward() {
        let skipValue = UserDefaults.standard.double(forKey: "skipIncrement")
        let finalSkip = skipValue > 0 ? skipValue : 10
        currentTimeVal = max(currentTimeVal - finalSkip, 0)
        player.seek(to: CMTime(seconds: currentTimeVal, preferredTimescale: 600)) { [weak self] finished in
            guard let self = self else { return }
            self.updateBufferValue()
        }
    }
    
    @objc func seekForward() {
        let skipValue = UserDefaults.standard.double(forKey: "skipIncrement")
        let finalSkip = skipValue > 0 ? skipValue : 10
        currentTimeVal = min(currentTimeVal + finalSkip, duration)
        player.seek(to: CMTime(seconds: currentTimeVal, preferredTimescale: 600)) { [weak self] finished in
            guard let self = self else { return }
            self.updateBufferValue()
        }
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
            player.pause()
            isPlaying = false
            playPauseButton.image = UIImage(systemName: "play.fill")
            
            if !isControlsVisible {
                isControlsVisible = true
                UIView.animate(withDuration: 0.2) {
                    self.controlsContainerView.alpha = 1.0
                    self.skip85Button.alpha = 0.8
                    self.view.layoutIfNeeded()
                }
            }
        } else {
            player.play()
            isPlaying = true
            playPauseButton.image = UIImage(systemName: "pause.fill")
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
        let aniListMutation = AniListMutation()
        aniListMutation.updateAnimeProgress(animeId: self.aniListID, episodeNumber: self.episodeNumber) { [weak self] result in
            guard let self = self else { return }
            
            switch result {
            case .success:
                self.aniListUpdatedSuccessfully = true
                Logger.shared.log("Successfully updated AniList progress for episode \(self.episodeNumber)", type: "General")
                
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
                        Logger.shared.log("AniList update will retry in \(delaySeconds)s (attempt \(self.aniListRetryCount)).", type: "Debug")
                        
                        DispatchQueue.main.asyncAfter(deadline: .now() + delaySeconds) {
                            self.tryAniListUpdate()
                        }
                    } else {
                        Logger.shared.log("AniList update reached max retries. No more attempts.", type: "Error")
                    }
                }
            }
        }
    }
    
    private func parseM3U8(url: URL, completion: @escaping () -> Void) {
        var request = URLRequest(url: url)
        request.addValue("\(module.metadata.baseUrl)", forHTTPHeaderField: "Referer")
        request.addValue("\(module.metadata.baseUrl)", forHTTPHeaderField: "Origin")
        request.addValue("Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/134.0.0.0 Safari/537.36",
                         forHTTPHeaderField: "User-Agent")
        
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
        }.resume()
    }
    
    private func switchToQuality(urlString: String) {
        guard let url = URL(string: urlString),
              currentQualityURL?.absoluteString != urlString else { return }
        
        let currentTime = player.currentTime()
        let wasPlaying = player.rate > 0
        
        var request = URLRequest(url: url)
        request.addValue("\(module.metadata.baseUrl)", forHTTPHeaderField: "Referer")
        request.addValue("\(module.metadata.baseUrl)", forHTTPHeaderField: "Origin")
        request.addValue("Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/134.0.0.0 Safari/537.36",
                         forHTTPHeaderField: "User-Agent")
        
        let asset = AVURLAsset(url: url, options: ["AVURLAssetHTTPHeaderFieldsKey": request.allHTTPHeaderFields ?? [:]])
        let playerItem = AVPlayerItem(asset: asset)
        
        player.replaceCurrentItem(with: playerItem)
        player.seek(to: currentTime)
        if wasPlaying {
            player.play()
        }
        
        currentQualityURL = url
        
        UserDefaults.standard.set(urlString, forKey: "lastSelectedQuality")
        qualityButton.menu = qualitySelectionMenu()
        
        if let selectedQuality = qualities.first(where: { $0.1 == urlString })?.0 {
            DropManager.shared.showDrop(title: "Quality: \(selectedQuality)",
                                        subtitle: "",
                                        duration: 0.5,
                                        icon: UIImage(systemName: "eye"))
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
        
        if url.absoluteString.contains(".m3u8") {
            isHLSStream = true
            baseM3U8URL = url
            currentQualityURL = url
            
            parseM3U8(url: url) { [weak self] in
                guard let self = self else { return }
                
                if let lastSelectedQuality = UserDefaults.standard.string(forKey: "lastSelectedQuality"),
                   self.qualities.contains(where: { $0.1 == lastSelectedQuality }) {
                    self.switchToQuality(urlString: lastSelectedQuality)
                }
                
                self.qualityButton.isHidden = false
                self.qualityButton.menu = self.qualitySelectionMenu()
                self.updateMarqueeConstraints()
            }
        } else {
            isHLSStream = false
            qualityButton.isHidden = true
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
            
            let subtitleOptionsMenu = UIMenu(title: "Subtitle Options", children: [
                subtitlesToggleAction, colorMenu, fontSizeMenu, shadowMenu, backgroundMenu, paddingMenu
            ])
            
            menuElements = [subtitleOptionsMenu]
        }
        
        return UIMenu(title: "", children: menuElements)
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
            DispatchQueue.main.async {
                self?.volumeViewModel.value = Double(newVol)
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
        player.rate = holdSpeed > 0 ? holdSpeed : 2.0
    }
    
    private func endHoldSpeed() {
        player?.rate = originalRate
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
                if reason == .toMinimizeStalls || reason == .evaluatingBufferingRate {
                    player.play()
                }
            }
        }
    }
    
    struct VolumeSliderContainer: View {
        @ObservedObject var volumeVM: VolumeViewModel
        var updateSystemSlider: ((Double) -> Void)? = nil // Optional callback if needed
        
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
        }
    }
}

// yes? Like the plural of the famous american rapper ye? -IBHRAD
// low taper fade the meme is massive -cranci
// cranci still doesnt have a job -seiike
// guys watch Clannad already - ibro
