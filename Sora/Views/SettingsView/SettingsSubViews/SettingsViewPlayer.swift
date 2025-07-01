//
//  SettingsViewPlayer.swift
//  Sora
//
//  Created by Francesco on 31/01/25.
//

import SwiftUI

fileprivate struct SettingsSection<Content: View>: View {
    let title: String
    let footer: String?
    let content: Content
    
    init(title: String, footer: String? = nil, @ViewBuilder content: () -> Content) {
        self.title = title
        self.footer = footer
        self.content = content()
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title.uppercased())
                .font(.footnote)
                .foregroundStyle(.gray)
                .padding(.horizontal, 20)
            
            VStack(spacing: 0) {
                content
            }
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(
                        LinearGradient(
                            gradient: Gradient(stops: [
                                .init(color: Color.accentColor.opacity(0.3), location: 0),
                                .init(color: Color.accentColor.opacity(0), location: 1)
                            ]),
                            startPoint: .top,
                            endPoint: .bottom
                        ),
                        lineWidth: 0.5
                    )
            )
            .padding(.horizontal, 20)
            
            if let footer = footer {
                Text(footer)
                    .font(.footnote)
                    .foregroundStyle(.gray)
                    .padding(.horizontal, 20)
                    .padding(.top, 4)
            }
        }
    }
}

fileprivate struct SettingsToggleRow: View {
    let icon: String
    let title: String
    @Binding var isOn: Bool
    var showDivider: Bool = true
    
    init(icon: String, title: String, isOn: Binding<Bool>, showDivider: Bool = true) {
        self.icon = icon
        self.title = title
        self._isOn = isOn
        self.showDivider = showDivider
    }
    
    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Image(systemName: icon)
                    .frame(width: 24, height: 24)
                    .foregroundStyle(.primary)
                
                Text(title)
                    .foregroundStyle(.primary)
                
                Spacer()
                
                Toggle("", isOn: $isOn)
                    .labelsHidden()
                    .tint(.accentColor.opacity(0.7))
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            
            if showDivider {
                Divider()
                    .padding(.horizontal, 16)
            }
        }
    }
}

fileprivate struct SettingsPickerRow<T: Hashable>: View {
    let icon: String
    let title: String
    let options: [T]
    let optionToString: (T) -> String
    @Binding var selection: T
    var showDivider: Bool = true
    
    init(icon: String, title: String, options: [T], optionToString: @escaping (T) -> String, selection: Binding<T>, showDivider: Bool = true) {
        self.icon = icon
        self.title = title
        self.options = options
        self.optionToString = optionToString
        self._selection = selection
        self.showDivider = showDivider
    }
    
    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Image(systemName: icon)
                    .frame(width: 24, height: 24)
                    .foregroundStyle(.primary)
                
                Text(title)
                    .foregroundStyle(.primary)
                
                Spacer()
                
                Menu {
                    ForEach(options, id: \.self) { option in
                        Button(action: { selection = option }) {
                            Text(optionToString(option))
                        }
                    }
                } label: {
                    Text(optionToString(selection))
                        .foregroundStyle(.gray)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            
            if showDivider {
                Divider()
                    .padding(.horizontal, 16)
            }
        }
    }
}

fileprivate struct SettingsStepperRow: View {
    let icon: String
    let title: String
    @Binding var value: Double
    let range: ClosedRange<Double>
    let step: Double
    var formatter: (Double) -> String = { "\(Int($0))" }
    var showDivider: Bool = true
    
    init(icon: String, title: String, value: Binding<Double>, range: ClosedRange<Double>, step: Double, formatter: @escaping (Double) -> String = { "\(Int($0))" }, showDivider: Bool = true) {
        self.icon = icon
        self.title = title
        self._value = value
        self.range = range
        self.step = step
        self.formatter = formatter
        self.showDivider = showDivider
    }
    
    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Image(systemName: icon)
                    .frame(width: 24, height: 24)
                    .foregroundStyle(.primary)
                
                Text(title)
                    .foregroundStyle(.primary)
                
                Spacer()
                
                Stepper(formatter(value), value: $value, in: range, step: step)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            
            if showDivider {
                Divider()
                    .padding(.horizontal, 16)
            }
        }
    }
}

struct SettingsViewPlayer: View {
    @AppStorage("externalPlayer") private var externalPlayer: String = "Sora"
    @AppStorage("alwaysLandscape") private var isAlwaysLandscape = false
    @AppStorage("rememberPlaySpeed") private var isRememberPlaySpeed = false
    @AppStorage("holdSpeedPlayer") private var holdSpeedPlayer: Double = 2.0
    @AppStorage("skipIncrement") private var skipIncrement: Double = 10.0
    @AppStorage("skipIncrementHold") private var skipIncrementHold: Double = 30.0
    @AppStorage("remainingTimePercentage") private var remainingTimePercentage: Double = 90.0
    @AppStorage("holdForPauseEnabled") private var holdForPauseEnabled = false
    @AppStorage("skip85Visible") private var skip85Visible: Bool = true
    @AppStorage("doubleTapSeekEnabled") private var doubleTapSeekEnabled: Bool = false
    @AppStorage("skipIntroOutroVisible") private var skipIntroOutroVisible: Bool = true
    @AppStorage("pipButtonVisible") private var pipButtonVisible: Bool = true
    @AppStorage("autoplayNext") private var autoplayNext: Bool = true
    
    @AppStorage("videoQualityWiFi") private var wifiQuality: String = VideoQualityPreference.defaultWiFiPreference.rawValue
    @AppStorage("videoQualityCellular") private var cellularQuality: String = VideoQualityPreference.defaultCellularPreference.rawValue
    
    private let mediaPlayers = ["Default", "Sora", "VLC", "OutPlayer", "Infuse", "nPlayer", "SenPlayer", "IINA", "TracyPlayer"]
    private let qualityOptions = VideoQualityPreference.allCases.map { $0.rawValue }
    
    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 24) {
                SettingsSection(
                    title: NSLocalizedString("Media Player", comment: ""),
                    footer: NSLocalizedString("Some features are limited to the Sora and Default player, such as ForceLandscape, holdSpeed and custom time skip increments.\n\nThe completion percentage setting determines at what point before the end of a video the app will mark it as completed on AniList and Trakt.", comment: "")
                ) {
                    SettingsPickerRow(
                        icon: "play.circle",
                        title: NSLocalizedString("Media Player", comment: ""),
                        options: mediaPlayers,
                        optionToString: { $0 },
                        selection: $externalPlayer
                    )
                    
                    SettingsToggleRow(
                        icon: "rotate.right",
                        title: NSLocalizedString("Force Landscape", comment: ""),
                        isOn: $isAlwaysLandscape
                    )
                    
                    SettingsToggleRow(
                        icon: "hand.tap",
                        title: NSLocalizedString("Two Finger Hold for Pause", comment: ""),
                        isOn: $holdForPauseEnabled,
                        showDivider: true
                    )
                    
                    SettingsToggleRow(
                        icon: "pip",
                        title: NSLocalizedString("Show PiP Button", comment: ""),
                        isOn: $pipButtonVisible,
                        showDivider: true
                    )
                    
                    SettingsToggleRow(
                        icon: "play.circle.fill",
                        title: NSLocalizedString("Autoplay Next", comment: ""),
                        isOn: $autoplayNext,
                        showDivider: true
                    )
                    
                    SettingsPickerRow(
                        icon: "timer",
                        title: NSLocalizedString("Completion Percentage", comment: ""),
                        options: [60.0, 70.0, 80.0, 90.0, 95.0, 100.0],
                        optionToString: { "\(Int($0))%" },
                        selection: $remainingTimePercentage,
                        showDivider: false
                    )
                }
                
                SettingsSection(title: NSLocalizedString("Speed Settings", comment: "")) {
                    SettingsToggleRow(
                        icon: "speedometer",
                        title: NSLocalizedString("Remember Playback speed", comment: ""),
                        isOn: $isRememberPlaySpeed
                    )
                    
                    SettingsStepperRow(
                        icon: "forward.fill",
                        title: NSLocalizedString("Hold Speed", comment: ""),
                        value: $holdSpeedPlayer,
                        range: 0.25...2.5,
                        step: 0.25,
                        formatter: { String(format: "%.2f", $0) },
                        showDivider: false
                    )
                }
                SettingsSection(
                    title: NSLocalizedString("Video Quality Preferences", comment: ""),
                    footer: NSLocalizedString("Choose preferred video resolution for WiFi and cellular connections. Higher resolutions use more data but provide better quality. If the exact quality isn't available, the closest option will be selected automatically.\n\nNote: Not all video sources and players support quality selection. This feature works best with HLS streams using the Sora player.", comment: "Footer explaining video quality settings for translators.")
                ) {
                    SettingsPickerRow(
                        icon: "wifi",
                        title: String(localized: "WiFi Quality"),
                        options: qualityOptions,
                        optionToString: { $0 },
                        selection: $wifiQuality
                    )
                    
                    SettingsPickerRow(
                        icon: "antenna.radiowaves.left.and.right",
                        title: String(localized: "Cellular Quality"),
                        options: qualityOptions,
                        optionToString: { $0 },
                        selection: $cellularQuality,
                        showDivider: false
                    )
                }
                
                SettingsSection(title: NSLocalizedString("Progress bar Marker Color", comment: "")) {
                    ColorPicker(NSLocalizedString("Segments Color", comment: ""), selection: Binding(
                        get: {
                            if let data = UserDefaults.standard.data(forKey: "segmentsColorData"),
                               let uiColor = try? NSKeyedUnarchiver.unarchiveTopLevelObjectWithData(data) as? UIColor {
                                return Color(uiColor)
                            }
                            return .yellow
                        },
                        set: { newColor in
                            let uiColor = UIColor(newColor)
                            if let data = try? NSKeyedArchiver.archivedData(
                                withRootObject: uiColor,
                                requiringSecureCoding: false
                            ) {
                                UserDefaults.standard.set(data, forKey: "segmentsColorData")
                            }
                        }
                    ))
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                }
                
                SettingsSection(
                    title: NSLocalizedString("Skip Settings", comment: ""),
                    footer: NSLocalizedString("Double tapping the screen on it's sides will skip with the short tap setting.", comment: "")
                ) {
                    SettingsStepperRow(
                        icon: "goforward",
                        title: NSLocalizedString("Tap Skip", comment: ""),
                        value: $skipIncrement,
                        range: 5...300,
                        step: 5,
                        formatter: { "\(Int($0))s" }
                    )
                    
                    SettingsStepperRow(
                        icon: "goforward.plus",
                        title: NSLocalizedString("Long press Skip", comment: ""),
                        value: $skipIncrementHold,
                        range: 5...300,
                        step: 5,
                        formatter: { "\(Int($0))s" }
                    )
                    
                    SettingsToggleRow(
                        icon: "hand.tap.fill",
                        title: NSLocalizedString("Double Tap to Seek", comment: ""),
                        isOn: $doubleTapSeekEnabled
                    )
                    
                    SettingsToggleRow(
                        icon: "forward.end",
                        title: NSLocalizedString("Show Skip 85s Button", comment: ""),
                        isOn: $skip85Visible
                    )
                    
                    SettingsToggleRow(
                        icon: "forward.frame",
                        title: NSLocalizedString("Show Skip Intro / Outro Buttons", comment: ""),
                        isOn: $skipIntroOutroVisible,
                        showDivider: false
                    )
                }
                
                SubtitleSettingsSection()
            }
            .padding(.vertical, 20)
        }
        .scrollViewBottomPadding()
        .navigationTitle(NSLocalizedString("Player", comment: ""))
    }
}

struct SubtitleSettingsSection: View {
    @State private var foregroundColor: String = SubtitleSettingsManager.shared.settings.foregroundColor
    @State private var fontSize: Double = SubtitleSettingsManager.shared.settings.fontSize
    @State private var shadowRadius: Double = SubtitleSettingsManager.shared.settings.shadowRadius
    @State private var backgroundEnabled: Bool = SubtitleSettingsManager.shared.settings.backgroundEnabled
    @State private var bottomPadding: Double = Double(SubtitleSettingsManager.shared.settings.bottomPadding)
    @State private var subtitleDelay: Double = SubtitleSettingsManager.shared.settings.subtitleDelay
    @AppStorage("subtitlesEnabled") private var subtitlesEnabled: Bool = true

    private let colors = ["white", "yellow", "green", "blue", "red", "purple"]
    private let shadowOptions = [0, 1, 3, 6]

    var body: some View {
        SettingsSection(title: NSLocalizedString("Subtitle Settings", comment: "")) {
            SettingsToggleRow(
                icon: "captions.bubble",
                title: NSLocalizedString("Enable Subtitles", comment: ""),
                isOn: $subtitlesEnabled,
                showDivider: true
            )
            .onChange(of: subtitlesEnabled) { newValue in
                SubtitleSettingsManager.shared.update { settings in
                    settings.enabled = newValue
                }
            }

            SettingsPickerRow(
                icon: "paintbrush",
                title: NSLocalizedString("Subtitle Color", comment: ""),
                options: colors,
                optionToString: { $0.capitalized },
                selection: $foregroundColor
            )
            .onChange(of: foregroundColor) { newValue in
                SubtitleSettingsManager.shared.update { settings in
                    settings.foregroundColor = newValue
                }
            }
            
            SettingsPickerRow(
                icon: "shadow",
                title: NSLocalizedString("Shadow", comment: ""),
                options: shadowOptions,
                optionToString: { "\($0)" },
                selection: Binding(
                    get: { Int(shadowRadius) },
                    set: { shadowRadius = Double($0) }
                )
            )
            .onChange(of: shadowRadius) { newValue in
                SubtitleSettingsManager.shared.update { settings in
                    settings.shadowRadius = newValue
                }
            }
            
            SettingsToggleRow(
                icon: "rectangle.fill",
                title: NSLocalizedString("Background Enabled", comment: ""),
                isOn: $backgroundEnabled
            )
            .onChange(of: backgroundEnabled) { newValue in
                SubtitleSettingsManager.shared.update { settings in
                    settings.backgroundEnabled = newValue
                }
            }
            
            SettingsStepperRow(
                icon: "textformat.size",
                title: NSLocalizedString("Font Size", comment: ""),
                value: $fontSize,
                range: 12...36,
                step: 1
            )
            .onChange(of: fontSize) { newValue in
                SubtitleSettingsManager.shared.update { settings in
                    settings.fontSize = newValue
                }
            }
            
            SettingsStepperRow(
                icon: "arrow.up.and.down",
                title: NSLocalizedString("Bottom Padding", comment: ""),
                value: $bottomPadding,
                range: 0...50,
                step: 1,
                showDivider: false
            )
            .onChange(of: bottomPadding) { newValue in
                SubtitleSettingsManager.shared.update { settings in
                    settings.bottomPadding = CGFloat(newValue)
                }
            }
        }
    }
}
