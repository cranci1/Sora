//
//  CustomPlayer.swift
//  test2
//
//  Created by Francesco on 23/02/25.
//

import UIKit
import AVKit
import SwiftUI
import AVFoundation

class SliderViewModel: ObservableObject {
    @Published var sliderValue: Double = 0.0
}

class CustomMediaPlayerViewController: UIViewController {
    let module: ScrapingModule
    let streamURL: String
    let fullUrl: String
    let titleText: String
    let episodeNumber: Int
    let episodeImageUrl: String
    let subtitlesURL: String?
    let onWatchNext: () -> Void
    
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
    var showWatchNextButton = true
    
    var watchNextButtonTimer: Timer?
    var isWatchNextRepositioned: Bool = false
    var isWatchNextVisible: Bool = false
    var lastDuration: Double = 0.0
    var watchNextButtonAppearedAt: Double?
    
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
    
    var playerViewController: AVPlayerViewController!
    var controlsContainerView: UIView!
    var playPauseButton: UIImageView!
    var backwardButton: UIImageView!
    var forwardButton: UIImageView!
    var subtitleLabel: UILabel!
    var dismissButton: UIButton!
    var menuButton: UIButton!
    var watchNextButton: UIButton!
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
    
    init(module: ScrapingModule,
         urlString: String,
         fullUrl: String,
         title: String,
         episodeNumber: Int,
         onWatchNext: @escaping () -> Void,
         subtitlesURL: String?,
         episodeImageUrl: String) {
        
        self.module = module
        self.streamURL = urlString
        self.fullUrl = fullUrl
        self.titleText = title
        self.episodeNumber = episodeNumber
        self.episodeImageUrl = episodeImageUrl
        self.onWatchNext = onWatchNext
        self.subtitlesURL = subtitlesURL
        
        super.init(nibName: nil, bundle: nil)
        
        guard let url = URL(string: urlString) else {
            fatalError("Invalid URL string")
        }
        var request = URLRequest(url: url)
        request.addValue("\(module.metadata.baseUrl)", forHTTPHeaderField: "Referer")
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
        setInitialPlayerRate()
        loadSubtitleSettings()
        setupPlayerViewController()
        setupControls()
        setupSkipAndDismissGestures()
        addInvisibleControlOverlays()
        setupSubtitleLabel()
        setupDismissButton()
        setupQualityButton()
        setupSpeedButton()
        setupMenuButton()
        setupSkip85Button()
        setupWatchNextButton()
        addTimeObserver()
        startUpdateTimer()
        setupAudioSession()
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            self?.checkForHLSStream()
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
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        NotificationCenter.default.addObserver(self, selector: #selector(playerItemDidChange), name: .AVPlayerItemNewAccessLogEntry, object: nil)
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        
        NotificationCenter.default.removeObserver(self, name: .AVPlayerItemNewAccessLogEntry, object: nil)
        
        if let playbackSpeed = player?.rate {
            UserDefaults.standard.set(playbackSpeed, forKey: "lastPlaybackSpeed")
        }
        player.pause()
        updateTimer?.invalidate()
        inactivityTimer?.invalidate()
        if let token = timeObserverToken {
            player.removeTimeObserver(token)
            timeObserverToken = nil
        }
        UserDefaults.standard.set(player.rate, forKey: "lastPlaybackSpeed")
        if let currentItem = player.currentItem, currentItem.duration.seconds > 0 {
            let progress = currentTimeVal / currentItem.duration.seconds
            let item = ContinueWatchingItem(
                id: UUID(),
                imageUrl: episodeImageUrl,
                episodeNumber: episodeNumber,
                mediaTitle: titleText,
                progress: progress,
                streamUrl: streamURL,
                fullUrl: fullUrl,
                subtitles: subtitlesURL,
                module: module
            )
            ContinueWatchingManager.shared.save(item: item)
        }
    }
    
    @objc private func playerItemDidChange() {
        DispatchQueue.main.async { [weak self] in
            if let self = self, self.qualityButton.isHidden && self.isHLSStream {
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
        
        let sliderView = MusicProgressSlider(
            value: Binding(get: { self.sliderViewModel.sliderValue },
                           set: { self.sliderViewModel.sliderValue = $0 }),
            inRange: 0...(duration > 0 ? duration : 1.0),
            activeFillColor: .white,
            fillColor: .white.opacity(0.5),
            emptyColor: .white.opacity(0.3),
            height: 30,
            onEditingChanged: { editing in
                self.isSliderEditing = editing
                if !editing {
                    self.player.seek(to: CMTime(seconds: self.sliderViewModel.sliderValue, preferredTimescale: 600))
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
        
        let backwardOverlay = UIButton(type: .custom)
        backwardOverlay.backgroundColor = .clear
        backwardOverlay.addTarget(self, action: #selector(seekBackward), for: .touchUpInside)
        view.addSubview(backwardOverlay)
        backwardOverlay.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            backwardOverlay.centerXAnchor.constraint(equalTo: backwardButton.centerXAnchor),
            backwardOverlay.centerYAnchor.constraint(equalTo: backwardButton.centerYAnchor),
            backwardOverlay.widthAnchor.constraint(equalTo: backwardButton.widthAnchor, constant: 20),
            backwardOverlay.heightAnchor.constraint(equalTo: backwardButton.heightAnchor, constant: 20)
        ])
        
        let forwardOverlay = UIButton(type: .custom)
        forwardOverlay.backgroundColor = .clear
        forwardOverlay.addTarget(self, action: #selector(seekForward), for: .touchUpInside)
        view.addSubview(forwardOverlay)
        forwardOverlay.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            forwardOverlay.centerXAnchor.constraint(equalTo: forwardButton.centerXAnchor),
            forwardOverlay.centerYAnchor.constraint(equalTo: forwardButton.centerYAnchor),
            forwardOverlay.widthAnchor.constraint(equalTo: forwardButton.widthAnchor, constant: 20),
            forwardOverlay.heightAnchor.constraint(equalTo: forwardButton.heightAnchor, constant: 20)
        ])
    }

    func setupSkipAndDismissGestures() {
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
        
        let swipeDownGesture = UISwipeGestureRecognizer(target: self, action: #selector(handleSwipeDown(_:)))
        swipeDownGesture.direction = .down
        view.addGestureRecognizer(swipeDownGesture)
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
        dismissButton = UIButton(type: .system)
        dismissButton.setImage(UIImage(systemName: "xmark"), for: .normal)
        dismissButton.tintColor = .white
        dismissButton.addTarget(self, action: #selector(dismissTapped), for: .touchUpInside)
        controlsContainerView.addSubview(dismissButton)
        dismissButton.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            dismissButton.leadingAnchor.constraint(equalTo: controlsContainerView.leadingAnchor, constant: 16),
            dismissButton.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 20),
            dismissButton.widthAnchor.constraint(equalToConstant: 40),
            dismissButton.heightAnchor.constraint(equalToConstant: 40)
        ])
    }
    
    func setupMenuButton() {
        menuButton = UIButton(type: .system)
        menuButton.setImage(UIImage(systemName: "text.bubble"), for: .normal)
        menuButton.tintColor = .white

        if let subtitlesURL = subtitlesURL, !subtitlesURL.isEmpty {
            menuButton.showsMenuAsPrimaryAction = true
            menuButton.menu = buildOptionsMenu()
        } else {
            menuButton.isHidden = true
        }

        controlsContainerView.addSubview(menuButton)
        menuButton.translatesAutoresizingMaskIntoConstraints = false

        NSLayoutConstraint.activate([
            menuButton.topAnchor.constraint(equalTo: controlsContainerView.topAnchor, constant: 20),
            menuButton.trailingAnchor.constraint(equalTo: speedButton.leadingAnchor, constant: -20),
            menuButton.widthAnchor.constraint(equalToConstant: 40),
            menuButton.heightAnchor.constraint(equalToConstant: 40)
        ])
    }
    
    func setupSpeedButton() {
        speedButton = UIButton(type: .system)
        speedButton.setImage(UIImage(systemName: "speedometer"), for: .normal)
        speedButton.tintColor = .white
        speedButton.showsMenuAsPrimaryAction = true
        speedButton.menu = speedChangerMenu()

        controlsContainerView.addSubview(speedButton)
        speedButton.translatesAutoresizingMaskIntoConstraints = false

        NSLayoutConstraint.activate([
            // Middle
            speedButton.topAnchor.constraint(equalTo: controlsContainerView.topAnchor, constant: 20),
            speedButton.trailingAnchor.constraint(equalTo: qualityButton.leadingAnchor, constant: -20),
            speedButton.widthAnchor.constraint(equalToConstant: 40),
            speedButton.heightAnchor.constraint(equalToConstant: 40)
        ])
    }
    
    func setupWatchNextButton() {
        watchNextButton = UIButton(type: .system)
        watchNextButton.setTitle("Play Next", for: .normal)
        watchNextButton.setImage(UIImage(systemName: "forward.fill"), for: .normal)
        watchNextButton.tintColor = .black
        watchNextButton.backgroundColor = .white
        watchNextButton.layer.cornerRadius = 25
        watchNextButton.setTitleColor(.black, for: .normal)
        watchNextButton.addTarget(self, action: #selector(watchNextTapped), for: .touchUpInside)
        watchNextButton.alpha = 0.0
        watchNextButton.isHidden = true
        
        view.addSubview(watchNextButton)
        watchNextButton.translatesAutoresizingMaskIntoConstraints = false
        
        watchNextButtonNormalConstraints = [
            watchNextButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            watchNextButton.bottomAnchor.constraint(equalTo: sliderHostingController!.view.centerYAnchor),
            watchNextButton.heightAnchor.constraint(equalToConstant: 50),
            watchNextButton.widthAnchor.constraint(greaterThanOrEqualToConstant: 120)
        ]
        
        watchNextButtonControlsConstraints = [
            watchNextButton.trailingAnchor.constraint(equalTo: sliderHostingController!.view.trailingAnchor),
            watchNextButton.bottomAnchor.constraint(equalTo: sliderHostingController!.view.topAnchor, constant: -5),
            watchNextButton.heightAnchor.constraint(equalToConstant: 50),
            watchNextButton.widthAnchor.constraint(greaterThanOrEqualToConstant: 120)
        ]
        
        NSLayoutConstraint.activate(watchNextButtonNormalConstraints)
    }
    
    func setupSkip85Button() {
        skip85Button = UIButton(type: .system)
        skip85Button.setTitle("Skip 85s", for: .normal)
        skip85Button.setImage(UIImage(systemName: "goforward"), for: .normal)
        skip85Button.tintColor = .black
        skip85Button.backgroundColor = .white
        skip85Button.layer.cornerRadius = 25
        skip85Button.setTitleColor(.black, for: .normal)
        skip85Button.alpha = 0.8
        skip85Button.addTarget(self, action: #selector(skip85Tapped), for: .touchUpInside)
        
        view.addSubview(skip85Button)
        skip85Button.translatesAutoresizingMaskIntoConstraints = false
        
        NSLayoutConstraint.activate([
            skip85Button.leadingAnchor.constraint(equalTo: sliderHostingController!.view.leadingAnchor),
            skip85Button.bottomAnchor.constraint(equalTo: sliderHostingController!.view.topAnchor, constant: -3),
            skip85Button.heightAnchor.constraint(equalToConstant: 50),
            skip85Button.widthAnchor.constraint(greaterThanOrEqualToConstant: 120)
        ])
    }
    
    private func setupQualityButton() {
        qualityButton = UIButton(type: .system)
        qualityButton.setImage(UIImage(systemName: "4k.tv"), for: .normal)
        qualityButton.tintColor = .white
        qualityButton.showsMenuAsPrimaryAction = true
        qualityButton.menu = qualitySelectionMenu()
        qualityButton.isHidden = true

        controlsContainerView.addSubview(qualityButton)
        qualityButton.translatesAutoresizingMaskIntoConstraints = false

        NSLayoutConstraint.activate([
            qualityButton.topAnchor.constraint(equalTo: controlsContainerView.topAnchor, constant: 20),
            qualityButton.trailingAnchor.constraint(equalTo: controlsContainerView.trailingAnchor, constant: -20),
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
        timeObserverToken = player.addPeriodicTimeObserver(forInterval: interval, queue: .main) { [weak self] time in
            guard let self = self,
                  let currentItem = self.player.currentItem,
                  currentItem.duration.seconds.isFinite else { return }
            
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
                self.sliderHostingController?.rootView = MusicProgressSlider(
                    value: Binding(get: { max(0, min(self.sliderViewModel.sliderValue, self.duration)) },
                                   set: { self.sliderViewModel.sliderValue = max(0, min($0, self.duration)) }),
                    inRange: 0...(self.duration > 0 ? self.duration : 1.0),
                    activeFillColor: .white,
                    fillColor: .white.opacity(0.5),
                    emptyColor: .white.opacity(0.3),
                    height: 30,
                    onEditingChanged: { editing in
                        self.isSliderEditing = editing
                        if !editing {
                            let seekTime = CMTime(seconds: self.sliderViewModel.sliderValue, preferredTimescale: 600)
                            self.player.seek(to: seekTime)
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
                    self.isWatchNextVisible = true
                    self.watchNextButtonAppearedAt = self.currentTimeVal
                    
                    if self.isControlsVisible {
                        NSLayoutConstraint.deactivate(self.watchNextButtonNormalConstraints)
                        NSLayoutConstraint.activate(self.watchNextButtonControlsConstraints)
                    } else {
                        NSLayoutConstraint.deactivate(self.watchNextButtonControlsConstraints)
                        NSLayoutConstraint.activate(self.watchNextButtonNormalConstraints)
                    }
                    self.watchNextButton.isHidden = false
                    self.watchNextButton.alpha = 0.0
                    UIView.animate(withDuration: 0.5, delay: 0, options: .curveEaseInOut, animations: {
                        self.watchNextButton.alpha = 0.8
                    }, completion: nil)
                }
                
                if let appearedAt = self.watchNextButtonAppearedAt,
                   (self.currentTimeVal - appearedAt) >= 5,
                   !self.isWatchNextRepositioned {
                    UIView.animate(withDuration: 0.5, delay: 0, options: .curveEaseInOut, animations: {
                        self.watchNextButton.alpha = 0.0
                    }, completion: { _ in
                        self.watchNextButton.isHidden = true
                        NSLayoutConstraint.deactivate(self.watchNextButtonNormalConstraints)
                        NSLayoutConstraint.activate(self.watchNextButtonControlsConstraints)
                        self.isWatchNextRepositioned = true
                    })
                }
            } else {
                self.watchNextButtonAppearedAt = nil
                self.isWatchNextVisible = false
                self.isWatchNextRepositioned = false
                UIView.animate(withDuration: 0.5, delay: 0, options: .curveEaseInOut, animations: {
                    self.watchNextButton.alpha = 0.0
                }, completion: { _ in
                    self.watchNextButton.isHidden = true
                })
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
        UIView.animate(withDuration: 0.5, delay: 0, options: .curveEaseInOut, animations: {
            self.controlsContainerView.alpha = self.isControlsVisible ? 1 : 0
            self.skip85Button.alpha = self.isControlsVisible ? 0.8 : 0
            
            if self.isControlsVisible {
                NSLayoutConstraint.deactivate(self.watchNextButtonNormalConstraints)
                NSLayoutConstraint.activate(self.watchNextButtonControlsConstraints)
                if self.isWatchNextRepositioned || self.isWatchNextVisible {
                    self.watchNextButton.isHidden = false
                    UIView.animate(withDuration: 0.5, animations: {
                        self.watchNextButton.alpha = 0.8
                    })
                }
            } else {
                if !self.isWatchNextRepositioned && self.isWatchNextVisible {
                    NSLayoutConstraint.deactivate(self.watchNextButtonControlsConstraints)
                    NSLayoutConstraint.activate(self.watchNextButtonNormalConstraints)
                }
                if self.isWatchNextRepositioned {
                    UIView.animate(withDuration: 0.5, animations: {
                        self.watchNextButton.alpha = 0.0
                    }, completion: { _ in
                        self.watchNextButton.isHidden = true
                    })
                }
            }
            self.view.layoutIfNeeded()
        })
    }
    
    @objc func seekBackwardLongPress(_ gesture: UILongPressGestureRecognizer) {
        if gesture.state == .began {
            let holdValue = UserDefaults.standard.double(forKey: "skipIncrementHold")
            let finalSkip = holdValue > 0 ? holdValue : 30
            currentTimeVal = max(currentTimeVal - finalSkip, 0)
            player.seek(to: CMTime(seconds: currentTimeVal, preferredTimescale: 600))
        }
    }
    
    @objc func seekForwardLongPress(_ gesture: UILongPressGestureRecognizer) {
        if gesture.state == .began {
            let holdValue = UserDefaults.standard.double(forKey: "skipIncrementHold")
            let finalSkip = holdValue > 0 ? holdValue : 30
            currentTimeVal = min(currentTimeVal + finalSkip, duration)
            player.seek(to: CMTime(seconds: currentTimeVal, preferredTimescale: 600))
        }
    }
    
    @objc func seekBackward() {
        let skipValue = UserDefaults.standard.double(forKey: "skipIncrement")
        let finalSkip = skipValue > 0 ? skipValue : 10
        currentTimeVal = max(currentTimeVal - finalSkip, 0)
        player.seek(to: CMTime(seconds: currentTimeVal, preferredTimescale: 600))
    }
    
    @objc func seekForward() {
        let skipValue = UserDefaults.standard.double(forKey: "skipIncrement")
        let finalSkip = skipValue > 0 ? skipValue : 10
        currentTimeVal = min(currentTimeVal + finalSkip, duration)
        player.seek(to: CMTime(seconds: currentTimeVal, preferredTimescale: 600))
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
            if !isControlsVisible {
                isControlsVisible = true
                UIView.animate(withDuration: 0.5) {
                    self.controlsContainerView.alpha = 1.0
                    self.skip85Button.alpha = 0.8
                    self.view.layoutIfNeeded()
                }
            }
            player.pause()
            playPauseButton.image = UIImage(systemName: "play.fill")
        } else {
            player.play()
            playPauseButton.image = UIImage(systemName: "pause.fill")
        }
        isPlaying.toggle()
    }
    
    @objc func sliderEditingEnded() {
        let newTime = sliderViewModel.sliderValue
        player.seek(to: CMTime(seconds: newTime, preferredTimescale: 600))
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
    
    private func parseM3U8(url: URL, completion: @escaping () -> Void) {
        var request = URLRequest(url: url)
        request.addValue("\(module.metadata.baseUrl)", forHTTPHeaderField: "Referer")
        request.addValue("Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/134.0.0.0 Safari/537.36", forHTTPHeaderField: "User-Agent")
        
        URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            guard let self = self, let data = data, let content = String(data: data, encoding: .utf8) else {
                print("Failed to load m3u8 file")
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
                       let resolutionEndRange = line[resolutionRange.upperBound...].range(of: ",") ?? line[resolutionRange.upperBound...].range(of: "\n") {
                        
                        let resolutionPart = String(line[resolutionRange.upperBound..<resolutionEndRange.lowerBound])
                        if let heightStr = resolutionPart.components(separatedBy: "x").last,
                           let height = Int(heightStr) {
                            
                            let nextLine = lines[index + 1].trimmingCharacters(in: .whitespacesAndNewlines)
                            let qualityName = getQualityName(for: height)
                            
                            var qualityURL = nextLine
                            if !nextLine.hasPrefix("http") && nextLine.contains(".m3u8") {
                                if let baseURL = self.baseM3U8URL {
                                    let baseURLString = baseURL.deletingLastPathComponent().absoluteString
                                    qualityURL = URL(string: nextLine, relativeTo: baseURL)?.absoluteString ?? baseURLString + "/" + nextLine
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
        guard let url = URL(string: urlString), currentQualityURL?.absoluteString != urlString else { return }
        
        let currentTime = player.currentTime()
        let wasPlaying = player.rate > 0
        
        var request = URLRequest(url: url)
        request.addValue("\(module.metadata.baseUrl)", forHTTPHeaderField: "Referer")
        request.addValue("Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/134.0.0.0 Safari/537.36", forHTTPHeaderField: "User-Agent")
        
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
            DropManager.shared.showDrop(title: "Quality: \(selectedQuality)", subtitle: "", duration: 0.5, icon: UIImage(systemName: "eye"))
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
            
            let subtitleOptionsMenu = UIMenu(title: "Subtitle Options", children: [subtitlesToggleAction, colorMenu, fontSizeMenu, shadowMenu, backgroundMenu, paddingMenu])
            
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
            Logger.shared.log("Failed to set up AVAudioSession: \(error)")
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
}

// yes? Like the plural of the famous american rapper ye? -IBHRAD
// low taper fade the meme is massive -cranci
// cranci still doesnt have a job -seiike
// guys watch Clannad already - ibro
