//
//  ReaderView.swift
//  Sora
//
//  Created by paul on 18/06/25.
//

import SwiftUI
import WebKit

class ChapterNavigator: ObservableObject {
    static let shared = ChapterNavigator()
    @Published var currentChapter: (moduleId: String, href: String, title: String, chapters: [[String: Any]])? = nil
}

extension UserDefaults {
    func cgFloat(forKey defaultName: String) -> CGFloat? {
        if let value = object(forKey: defaultName) as? NSNumber {
            return CGFloat(value.doubleValue)
        }
        return nil
    }
    
    func set(_ value: CGFloat, forKey defaultName: String) {
        set(NSNumber(value: Double(value)), forKey: defaultName)
    }
}

struct ReaderView: View {
    let moduleId: String
    let chapterHref: String
    let chapterTitle: String
    let chapters: [[String: Any]]
    
    @State private var htmlContent: String = ""
    @State private var isLoading: Bool = true
    @State private var error: Error?
    @State private var isHeaderVisible: Bool = true
    @State private var fontSize: CGFloat = 16
    @State private var selectedFont: String = "-apple-system"
    @State private var fontWeight: String = "normal"
    @State private var isAutoScrolling: Bool = false
    @State private var autoScrollSpeed: Double = 1.0
    @State private var autoScrollTimer: Timer?
    @State private var selectedColorPreset: Int = 0
    @State private var isSettingsExpanded: Bool = false
    @State private var textAlignment: String = "left"
    @State private var lineSpacing: CGFloat = 1.6
    @State private var margin: CGFloat = 4
    @State private var readingProgress: Double = 0.0
    @State private var lastProgressUpdate: Date = Date()
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var tabBarController: TabBarController
    @StateObject private var navigator = ChapterNavigator.shared
    
    private let fontOptions = [
        ("-apple-system", "System"),
        ("Georgia", "Georgia"),
        ("Times New Roman", "Times"),
        ("Helvetica", "Helvetica"),
        ("Charter", "Charter"),
        ("New York", "New York")
    ]
    private let weightOptions = [
        ("300", "Light"),
        ("normal", "Regular"),
        ("600", "Semibold"),
        ("bold", "Bold")
    ]
    
    private let alignmentOptions = [
        ("left", "Left", "text.alignleft"),
        ("center", "Center", "text.aligncenter"),
        ("right", "Right", "text.alignright"),
        ("justify", "Justify", "text.justify")
    ]
    
    private let colorPresets = [
        (name: "Pure", background: "#ffffff", text: "#000000"),
        (name: "Warm", background: "#f9f1e4", text: "#4f321c"),
        (name: "Slate", background: "#49494d", text: "#d7d7d8"),
        (name: "Off-Black", background: "#121212", text: "#EAEAEA"),
        (name: "Dark", background: "#000000", text: "#ffffff")
    ]
    
    private var currentTheme: (background: Color, text: Color) {
        let preset = colorPresets[selectedColorPreset]
        return (
            background: Color(hex: preset.background),
            text: Color(hex: preset.text)
        )
    }
    
    init(moduleId: String, chapterHref: String, chapterTitle: String, chapters: [[String: Any]] = []) {
        self.moduleId = moduleId
        self.chapterHref = chapterHref
        self.chapterTitle = chapterTitle
        self.chapters = chapters
        
        _fontSize = State(initialValue: UserDefaults.standard.cgFloat(forKey: "readerFontSize") ?? 16)
        _selectedFont = State(initialValue: UserDefaults.standard.string(forKey: "readerFontFamily") ?? "-apple-system")
        _fontWeight = State(initialValue: UserDefaults.standard.string(forKey: "readerFontWeight") ?? "normal")
        _selectedColorPreset = State(initialValue: UserDefaults.standard.integer(forKey: "readerColorPreset"))
        _textAlignment = State(initialValue: UserDefaults.standard.string(forKey: "readerTextAlignment") ?? "left")
        _lineSpacing = State(initialValue: UserDefaults.standard.cgFloat(forKey: "readerLineSpacing") ?? 1.6)
        _margin = State(initialValue: UserDefaults.standard.cgFloat(forKey: "readerMargin") ?? 4)
    }
    
    var body: some View {
        ZStack(alignment: .bottom) {
            currentTheme.background.ignoresSafeArea()
            
            if isLoading {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: currentTheme.text))
                    .onDisappear {
                        stopAutoScroll()
                    }
            } else if let error = error {
                VStack {
                    Text("Error loading chapter")
                        .font(.headline)
                        .foregroundColor(currentTheme.text)
                    Text(error.localizedDescription)
                        .font(.subheadline)
                        .foregroundColor(currentTheme.text.opacity(0.7))
                }
            } else {
                ZStack {
                    Color.clear
                        .contentShape(Rectangle())
                        .onTapGesture {
                            withAnimation(.easeInOut(duration: 0.6)) {
                                isHeaderVisible.toggle()
                                if !isHeaderVisible {
                                    isSettingsExpanded = false
                                }
                            }
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)

                                    HTMLView(
                    htmlContent: htmlContent,
                    fontSize: fontSize,
                    fontFamily: selectedFont,
                    fontWeight: fontWeight,
                    textAlignment: textAlignment,
                    lineSpacing: lineSpacing,
                    margin: margin,
                    isAutoScrolling: $isAutoScrolling,
                    autoScrollSpeed: autoScrollSpeed,
                    colorPreset: colorPresets[selectedColorPreset],
                    chapterHref: chapterHref,
                    onProgressChanged: { progress in
                        self.readingProgress = progress
                        
                        // Update progress more frequently (every 2 seconds)
                        if Date().timeIntervalSince(self.lastProgressUpdate) > 2.0 {
                            self.updateReadingProgress(progress: progress)
                            self.lastProgressUpdate = Date()
                            Logger.shared.log("Progress updated to \(progress)", type: "Debug")
                        }
                    }
                )
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .padding(.horizontal)
                    .simultaneousGesture(TapGesture().onEnded {
                        withAnimation(.easeInOut(duration: 0.6)) {
                            isHeaderVisible.toggle()
                            if !isHeaderVisible {
                                isSettingsExpanded = false
                            }
                        }
                    })
                }
                .padding(.top, isHeaderVisible ? 0 : (UIApplication.shared.windows.first?.safeAreaInsets.top ?? 0))
            }
            
            headerView
                .opacity(isHeaderVisible ? 1 : 0)
                .offset(y: isHeaderVisible ? 0 : -100)
                .allowsHitTesting(isHeaderVisible)
                .animation(.easeInOut(duration: 0.6), value: isHeaderVisible)
                .zIndex(1) 
            
            if isHeaderVisible {
            footerView
                    .transition(.move(edge: .bottom))
                    .zIndex(2) 
            }
        }
        .navigationBarHidden(true)
        .navigationBarBackButtonHidden(true)
        .ignoresSafeArea()
        .onAppear {
            tabBarController.hideTabBar()
            UserDefaults.standard.set(chapterHref, forKey: "lastReadChapter")
            saveReadingProgress()
        }
        .onDisappear {
            if let next = navigator.currentChapter,
               next.href != chapterHref {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                    if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                       let window = windowScene.windows.first,
                       let rootVC = window.rootViewController {
                        let nextReader = ReaderView(
                            moduleId: next.moduleId,
                            chapterHref: next.href,
                            chapterTitle: next.title,
                            chapters: next.chapters
                        )
                        .environmentObject(tabBarController)
                        
                        let hostingController = UIHostingController(rootView: nextReader)
                        hostingController.modalPresentationStyle = .fullScreen
                        hostingController.modalTransitionStyle = .crossDissolve
                        
                        findTopViewController.findViewController(rootVC).present(hostingController, animated: true)
                    }
                }
            }
        }
        .task {
            do {
                let content = try await JSController.shared.extractText(moduleId: moduleId, href: chapterHref)
                if !content.isEmpty {
                    htmlContent = content
                    isLoading = false
                } else {
                    throw JSError.invalidResponse
                }
            } catch {
                self.error = error
                isLoading = false
            }
        }
    }
    
    private func stopAutoScroll() {
        autoScrollTimer?.invalidate()
        autoScrollTimer = nil
        isAutoScrolling = false
    }
    
    private var headerView: some View {
        VStack {
            ZStack(alignment: .top) {
                // Base header content
                HStack {
                    Button(action: {
                        dismiss()
                    }) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 20, weight: .bold))
                            .foregroundColor(currentTheme.text)
                            .padding(12)
                            .background(currentTheme.background.opacity(0.8))
                            .clipShape(Circle())
                            .circularGradientOutline()
                    }
                    .padding(.leading)
                    
                    Text(chapterTitle)
                        .font(.headline)
                        .foregroundColor(currentTheme.text)
                        .lineLimit(1)
                        .truncationMode(.tail)
                    
                    Spacer()

                    Color.clear
                        .frame(width: 44, height: 44)
                        .padding(.trailing)
                }
                .opacity(isHeaderVisible ? 1 : 0)
                .offset(y: isHeaderVisible ? 0 : -100)
                .animation(.easeInOut(duration: 0.6), value: isHeaderVisible)
                .contentShape(Rectangle())
                .onTapGesture {
                    withAnimation(.easeInOut(duration: 0.6)) {
                        isHeaderVisible = false
                        isSettingsExpanded = false
                    }
                }

                HStack {
                    Spacer()
                    HStack(spacing: 8) {
                        Button(action: {
                            goToNextChapter()
                        }) {
                            Image(systemName: "forward.end.fill")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundColor(currentTheme.text)
                                .padding(8)
                                .background(currentTheme.background.opacity(0.8))
                                .clipShape(Circle())
                                .circularGradientOutline()
                        }
                        .opacity(isHeaderVisible ? 1 : 0)
                        .offset(y: isHeaderVisible ? 0 : -100)
                        .animation(.easeInOut(duration: 0.6), value: isHeaderVisible)
                        
                        ZStack(alignment: .topTrailing) {
                            Button(action: {
                                withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                                    isSettingsExpanded.toggle()
                                }
                            }) {
                                Image(systemName: "ellipsis")
                                    .font(.system(size: 18, weight: .bold))
                                    .foregroundColor(currentTheme.text)
                                    .padding(12)
                                    .background(currentTheme.background.opacity(0.8))
                                    .clipShape(Circle())
                                    .circularGradientOutline()
                                    .rotationEffect(.degrees(isSettingsExpanded ? 90 : 0))
                            }
                            .opacity(isHeaderVisible ? 1 : 0)
                            .offset(y: isHeaderVisible ? 0 : -100)
                            .animation(.easeInOut(duration: 0.6), value: isHeaderVisible)
                            
                            if isSettingsExpanded {
                                VStack(spacing: 8) {
                                    Menu {
                                        VStack {
                                            Text("Font Size: \(Int(fontSize))pt")
                                                .font(.headline)
                                                .padding(.bottom, 8)
                                            
                                            Slider(value: Binding(
                                                get: { fontSize },
                                                set: { newValue in
                                                    fontSize = newValue
                                                    UserDefaults.standard.set(newValue, forKey: "readerFontSize")
                                                }
                                            ), in: 12...32, step: 1) {
                                                Text("Font Size")
                                            }
                                            .padding(.horizontal)
                                        }
                                        .padding()
                                    } label: {
                                        settingsButtonLabel(icon: "textformat.size")
                                    }
                                    
                                    Menu {
                                        ForEach(fontOptions, id: \.0) { font in
                                            Button(action: {
                                                selectedFont = font.0
                                                UserDefaults.standard.set(font.0, forKey: "readerFontFamily")
                                            }) {
                                                HStack {
                                                    Text(font.1)
                                                        .font(.custom(font.0, size: 16))
                                                    Spacer()
                                                    if selectedFont == font.0 {
                                                        Image(systemName: "checkmark")
                                                            .foregroundColor(.blue)
                                                    }
                                                }
                                            }
                                        }
                                    } label: {
                                        settingsButtonLabel(icon: "textformat.characters")
                                    }
                                    
                                    Menu {
                                        ForEach(weightOptions, id: \.0) { weight in
                                            Button(action: {
                                                fontWeight = weight.0
                                                UserDefaults.standard.set(weight.0, forKey: "readerFontWeight")
                                            }) {
                                                HStack {
                                                    Text(weight.1)
                                                        .fontWeight(weight.0 == "300" ? .light :
                                                                  weight.0 == "normal" ? .regular :
                                                                  weight.0 == "600" ? .semibold : .bold)
                                                    Spacer()
                                                    if fontWeight == weight.0 {
                                                        Image(systemName: "checkmark")
                                                            .foregroundColor(.blue)
                                                    }
                                                }
                                            }
                                        }
                                    } label: {
                                        settingsButtonLabel(icon: "bold")
                                    }

                                    Menu {
                                        ForEach(0..<colorPresets.count, id: \.self) { index in
                                            Button(action: {
                                                selectedColorPreset = index
                                                UserDefaults.standard.set(index, forKey: "readerColorPreset")
                                            }) {
                                                Label {
                                                    HStack {
                                                        Text(colorPresets[index].name)
                                                        Spacer()
                                                        if selectedColorPreset == index {
                                                            Image(systemName: "checkmark")
                                                                .foregroundColor(.blue)
                                                        }
                                                    }
                                                } icon: {
                                                    Circle()
                                                        .fill(Color(hex: colorPresets[index].background))
                                                        .frame(width: 16, height: 16)
                                                        .overlay(
                                                            Circle()
                                                                .stroke(Color(hex: colorPresets[index].text), lineWidth: 1)
                                                        )
                                                }
                                            }
                                        }
                                    } label: {
                                        settingsButtonLabel(icon: "paintpalette")
                                    }

                                    Menu {
                                        VStack {
                                            Text("Line Spacing: \(String(format: "%.1f", lineSpacing))")
                                                .font(.headline)
                                                .padding(.bottom, 8)
                                            
                                            Slider(value: Binding(
                                                get: { lineSpacing },
                                                set: { newValue in
                                                    lineSpacing = newValue
                                                    UserDefaults.standard.set(newValue, forKey: "readerLineSpacing")
                                                }
                                            ), in: 1.0...3.0, step: 0.1) {
                                                Text("Line Spacing")
                                            }
                                            .padding(.horizontal)
                                        }
                                        .padding()
                                    } label: {
                                        Image(systemName: "arrow.left.and.right.text.vertical")
                                            .font(.system(size: 16, weight: .bold))
                                            .foregroundColor(currentTheme.text)
                                            .padding(10)
                                            .background(currentTheme.background.opacity(0.8))
                                            .clipShape(Circle())
                                            .circularGradientOutline()
                                            .rotationEffect(.degrees(-90))
                                    }
                                    
                                    Menu {
                                        VStack {
                                            Text("Margin: \(Int(margin))px")
                                                .font(.headline)
                                                .padding(.bottom, 8)
                                            
                                            Slider(value: Binding(
                                                get: { margin },
                                                set: { newValue in
                                                    margin = newValue
                                                    UserDefaults.standard.set(newValue, forKey: "readerMargin")
                                                }
                                            ), in: 0...30, step: 1) {
                                                Text("Margin")
                                            }
                                            .padding(.horizontal)
                                        }
                                        .padding()
                                    } label: {
                                        settingsButtonLabel(icon: "rectangle.inset.filled")
                                    }

                                    Menu {
                                        ForEach(alignmentOptions, id: \.0) { alignment in
                                            Button(action: {
                                                textAlignment = alignment.0
                                                UserDefaults.standard.set(alignment.0, forKey: "readerTextAlignment")
                                            }) {
                                                HStack {
                                                    Image(systemName: alignment.2)
                                                    Text(alignment.1)
                                                    Spacer()
                                                    if textAlignment == alignment.0 {
                                                        Image(systemName: "checkmark")
                                                            .foregroundColor(.blue)
                                                    }
                                                }
                                            }
                                        }
                                    } label: {
                                        settingsButtonLabel(icon: "text.alignleft")
                                    }
                                }
                                .padding(.top, 50) 
                                .transition(.opacity)
                            }
                        }
                        .padding(.trailing)
                    }
                }
            }
            .padding(.top, (UIApplication.shared.windows.first?.safeAreaInsets.top ?? 0))
            .padding(.bottom, 30)
            .background(ProgressiveBlurView())
            
            Spacer()
        }
        .ignoresSafeArea()
    }
    
    private var footerView: some View {
        VStack {
            Spacer()
            
            HStack(spacing: 20) {
                Spacer()
                Button(action: {
                    isAutoScrolling.toggle()
                }) {
                    Image(systemName: isAutoScrolling ? "pause.fill" : "play.fill")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(isAutoScrolling ? .red : currentTheme.text)
                        .padding(12)
                        .background(currentTheme.background.opacity(0.8))
                        .clipShape(Circle())
                        .circularGradientOutline()
                }
                .contextMenu {
                    VStack {
                        Text("Auto Scroll Speed")
                            .font(.headline)
                            .padding(.bottom, 8)
                        
                        Slider(value: $autoScrollSpeed, in: 0.2...3.0, step: 0.1) {
                            Text("Speed")
                        }
                        .padding(.horizontal)
                        
                        Text("Speed: \(String(format: "%.1f", autoScrollSpeed))x")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .padding(.top, 4)
                    }
                    .padding()
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 20)
            .padding(.bottom, (UIApplication.shared.windows.first?.safeAreaInsets.bottom ?? 0) + 20)
            .frame(maxWidth: .infinity)
            .background(ProgressiveBlurView())
            .opacity(isHeaderVisible ? 1 : 0)
            .offset(y: isHeaderVisible ? 0 : 100)
            .animation(.easeInOut(duration: 0.6), value: isHeaderVisible)
            .contentShape(Rectangle())
            .onTapGesture {
                withAnimation(.easeInOut(duration: 0.6)) {
                    isHeaderVisible = false
                    isSettingsExpanded = false
                }
            }
        }
        .ignoresSafeArea()
    }
    
    private func settingsButtonLabel(icon: String) -> some View {
        Image(systemName: icon)
            .font(.system(size: 16, weight: .bold))
            .foregroundColor(currentTheme.text)
            .padding(10)
            .background(currentTheme.background.opacity(0.8))
            .clipShape(Circle())
            .circularGradientOutline()
    }
    
    private func goToNextChapter() {
        guard let currentIndex = chapters.firstIndex(where: { $0["href"] as? String == chapterHref }),
              currentIndex + 1 < chapters.count else {
            // Show a message when there's no next chapter
            DropManager.shared.showDrop(
                title: NSLocalizedString("No Next Chapter", comment: ""),
                subtitle: "",
                duration: 0.5,
                icon: UIImage(systemName: "xmark.circle")
            )
            return
        }
        
        let nextChapter = chapters[currentIndex + 1]
        if let nextHref = nextChapter["href"] as? String,
           let nextTitle = nextChapter["title"] as? String {
            // Mark current chapter as completed
            updateReadingProgress(progress: 1.0)
            
            // Set the next chapter in the navigator
            navigator.currentChapter = (moduleId: moduleId, href: nextHref, title: nextTitle, chapters: chapters)
            dismiss()
        }
    }
    
    private func saveReadingProgress() {
        // Find the current novel title and chapter number from the chapters
        var mediaTitle = "Unknown Novel"
        var currentChapterNumber = 1
        
        // Log all chapter data to help debug the title extraction
        Logger.shared.log("All chapter data for debugging:", type: "Debug")
        for (index, chapter) in chapters.enumerated() {
            let keys = chapter.keys.joined(separator: ", ")
            Logger.shared.log("Chapter \(index) keys: \(keys)", type: "Debug")
            
            // Print some key values if they exist
            if let title = chapter["title"] as? String {
                Logger.shared.log("Chapter \(index) title: \(title)", type: "Debug")
            }
            if let number = chapter["number"] as? Int {
                Logger.shared.log("Chapter \(index) number: \(number)", type: "Debug")
            }
        }
        
        // Don't try to extract from moduleId if it looks like a UUID
        // UUIDs typically have this format: XXXXXXXX-XXXX-XXXX-XXXX-XXXXXXXXXXXX
        let uuidPattern = "^[0-9A-Fa-f]{8}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{12}$"
        let isUUID = moduleId.range(of: uuidPattern, options: .regularExpression, range: nil, locale: nil) != nil
        
        if !isUUID {
            // Try extracting from moduleId if it's not a UUID
            let components = moduleId.components(separatedBy: "-")
            if components.count > 1 {
                let potentialTitle = components.dropLast().joined(separator: "-")
                    .replacingOccurrences(of: "_", with: " ")
                    .capitalized
                
                if !potentialTitle.isEmpty && potentialTitle != "Unknown" {
                    mediaTitle = potentialTitle
                    Logger.shared.log("Extracted title from moduleId: \(mediaTitle)", type: "Debug")
                }
            }
        }
        
        // If still unknown, try to extract from all chapter data
        if mediaTitle == "Unknown Novel" {
            for chapter in chapters {
                // Check for novel title in various fields
                for key in ["novelTitle", "mediaTitle", "seriesTitle", "series", "bookTitle", "mangaTitle", "title"] {
                    if let title = chapter[key] as? String, !title.isEmpty, title != "Chapter" {
                        // If the title contains "Chapter", it's probably not the novel title
                        if !title.lowercased().contains("chapter") {
                            mediaTitle = title
                            Logger.shared.log("Extracted title from key \(key): \(mediaTitle)", type: "Debug")
                            break
                        }
                    }
                }
                
                if mediaTitle != "Unknown Novel" {
                    break
                }
            }
        }
        
        // Try to extract from the URL if it contains book or novel information
        if mediaTitle == "Unknown Novel" && !chapterHref.isEmpty {
            // Extract from URL patterns like https://novelfire.net/book/lord-of-the-mysteries/chapter-6
            if let url = URL(string: chapterHref) {
                let pathComponents = url.pathComponents
                
                // Look for "book" or "novel" in the path
                for (index, component) in pathComponents.enumerated() {
                    if component == "book" || component == "novel" {
                        // The next component is likely the book title
                        if index + 1 < pathComponents.count {
                            let bookTitle = pathComponents[index + 1]
                                .replacingOccurrences(of: "-", with: " ")
                                .replacingOccurrences(of: "_", with: " ")
                                .capitalized
                            
                            if !bookTitle.isEmpty {
                                mediaTitle = bookTitle
                                Logger.shared.log("Extracted title from URL: \(mediaTitle)", type: "Debug")
                                break
                            }
                        }
                    }
                }
            }
        }
        
        // If still unknown, try to extract from chapter title
        if mediaTitle == "Unknown Novel" && !chapterTitle.isEmpty {
            // Often chapter titles are like "Series Name - Chapter X" or "Series Name: Chapter X"
            for separator in [" - ", " – ", ": ", " | ", " ~ "] {
                if let range = chapterTitle.range(of: separator) {
                    let potentialTitle = chapterTitle[..<range.lowerBound].trimmingCharacters(in: .whitespacesAndNewlines)
                    if !potentialTitle.isEmpty && !potentialTitle.lowercased().contains("chapter") {
                        mediaTitle = String(potentialTitle)
                        Logger.shared.log("Extracted title from chapter title with separator \(separator): \(mediaTitle)", type: "Debug")
                        break
                    }
                }
            }
            
            // If still unknown and the title contains "Chapter", extract everything before "Chapter"
            if mediaTitle == "Unknown Novel" && chapterTitle.lowercased().contains("chapter") {
                if let range = chapterTitle.range(of: "Chapter", options: .caseInsensitive) {
                    let potentialTitle = chapterTitle[..<range.lowerBound].trimmingCharacters(in: .whitespacesAndNewlines)
                    if !potentialTitle.isEmpty {
                        mediaTitle = String(potentialTitle)
                        Logger.shared.log("Extracted title from chapter title before 'Chapter': \(mediaTitle)", type: "Debug")
                    }
                }
            }
        }
        
        // Get chapter number
        if let currentIndex = chapters.firstIndex(where: { $0["href"] as? String == chapterHref }) {
            currentChapterNumber = chapters[currentIndex]["number"] as? Int ?? currentIndex + 1
        }
        
        // Get the stored progress or use 0 as default
        var progress = UserDefaults.standard.double(forKey: "readingProgress_\(chapterHref)") 
        
        // Always set at least 1% progress when opening a chapter
        if progress < 0.01 {
            progress = 0.01
        }
        
        // Log the data we're saving for debugging
        Logger.shared.log("Saving continue reading item: title=\(mediaTitle), chapter=\(chapterTitle), number=\(currentChapterNumber), href=\(chapterHref), progress=\(progress)", type: "Debug")
        
        let item = ContinueReadingItem(
            mediaTitle: mediaTitle,
            chapterTitle: chapterTitle,
            chapterNumber: currentChapterNumber,
            imageUrl: "", // This will be updated when we have image URLs for chapters
            href: chapterHref,
            moduleId: moduleId,
            progress: progress,
            totalChapters: chapters.count,
            lastReadDate: Date()
        )
        
        ContinueReadingManager.shared.save(item: item)
    }
    
    private func updateReadingProgress(progress: Double) {
        // Round up to 100% if very close
        let roundedProgress = progress >= 0.95 ? 1.0 : progress
        
        UserDefaults.standard.set(roundedProgress, forKey: "readingProgress_\(chapterHref)")
        
        // Find the current novel title and chapter number from the chapters
        var mediaTitle = "Unknown Novel"
        var currentChapterNumber = 1
        
        // Try extracting from moduleId first (it often contains the novel name)
        let components = moduleId.components(separatedBy: "-")
        if components.count > 1 {
            let potentialTitle = components.dropLast().joined(separator: "-")
                .replacingOccurrences(of: "_", with: " ")
                .capitalized
            
            if !potentialTitle.isEmpty && potentialTitle != "Unknown" {
                mediaTitle = potentialTitle
            }
        }
        
        // If still unknown, try to extract from all chapter data
        if mediaTitle == "Unknown Novel" {
            for chapter in chapters {
                // Check for novel title in various fields
                for key in ["novelTitle", "mediaTitle", "seriesTitle", "series", "bookTitle", "mangaTitle", "title"] {
                    if let title = chapter[key] as? String, !title.isEmpty, title != "Chapter" {
                        // If the title contains "Chapter", it's probably not the novel title
                        if !title.lowercased().contains("chapter") {
                            mediaTitle = title
                            break
                        }
                    }
                }
                
                if mediaTitle != "Unknown Novel" {
                    break
                }
            }
        }
        
        // If still unknown, try to extract from chapter title
        if mediaTitle == "Unknown Novel" && !chapterTitle.isEmpty {
            // Often chapter titles are like "Series Name - Chapter X" or "Series Name: Chapter X"
            for separator in [" - ", " – ", ": ", " | ", " ~ "] {
                if let range = chapterTitle.range(of: separator) {
                    let potentialTitle = chapterTitle[..<range.lowerBound].trimmingCharacters(in: .whitespacesAndNewlines)
                    if !potentialTitle.isEmpty && !potentialTitle.lowercased().contains("chapter") {
                        mediaTitle = String(potentialTitle)
                        break
                    }
                }
            }
            
            // If still unknown and the title contains "Chapter", extract everything before "Chapter"
            if mediaTitle == "Unknown Novel" && chapterTitle.lowercased().contains("chapter") {
                if let range = chapterTitle.range(of: "Chapter", options: .caseInsensitive) {
                    let potentialTitle = chapterTitle[..<range.lowerBound].trimmingCharacters(in: .whitespacesAndNewlines)
                    if !potentialTitle.isEmpty {
                        mediaTitle = String(potentialTitle)
                    }
                }
            }
        }
        
        // Get chapter number
        if let currentIndex = chapters.firstIndex(where: { $0["href"] as? String == chapterHref }) {
            currentChapterNumber = chapters[currentIndex]["number"] as? Int ?? currentIndex + 1
        }
        
        // Log the progress update
        Logger.shared.log("Updating reading progress: \(roundedProgress) for \(chapterHref), title: \(mediaTitle)", type: "Debug")
        
        // Check if we should consider this chapter completed
        let isCompleted = roundedProgress >= 0.98
        
        // If completed, we'll show notification but still keep in continue reading
        // until user explicitly removes it or moves to next chapter
        if isCompleted && readingProgress < 0.98 {
            DropManager.shared.showDrop(
                title: NSLocalizedString("Chapter Completed", comment: ""),
                subtitle: "",
                duration: 0.5,
                icon: UIImage(systemName: "checkmark.circle")
            )
            Logger.shared.log("Chapter marked as completed", type: "Debug")
        }
        
        let item = ContinueReadingItem(
            mediaTitle: mediaTitle,
            chapterTitle: chapterTitle,
            chapterNumber: currentChapterNumber,
            imageUrl: "", // This will be updated when we have image URLs for chapters
            href: chapterHref,
            moduleId: moduleId,
            progress: roundedProgress,
            totalChapters: chapters.count,
            lastReadDate: Date()
        )
        
        ContinueReadingManager.shared.save(item: item)
    }
}

struct ColorPreviewCircle: View {
    let backgroundColor: String
    let textColor: String
    
    var body: some View {
        ZStack {
            Circle()
                .fill(
                    LinearGradient(
                        colors: [
                            Color(hex: backgroundColor),
                            Color(hex: textColor)
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
        }
    }
}

struct HTMLView: UIViewRepresentable {
    let htmlContent: String
    let fontSize: CGFloat
    let fontFamily: String
    let fontWeight: String
    let textAlignment: String
    let lineSpacing: CGFloat
    let margin: CGFloat
    @Binding var isAutoScrolling: Bool
    let autoScrollSpeed: Double
    let colorPreset: (name: String, background: String, text: String)
    let chapterHref: String?
    
    // Reading progress tracking
    var onProgressChanged: ((Double) -> Void)? = nil
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    // Cleanup when the view disappears
    static func dismantleUIView(_ uiView: WKWebView, coordinator: Coordinator) {
        coordinator.stopProgressTracking()
    }
    
    class Coordinator: NSObject, WKNavigationDelegate, WKScriptMessageHandler {
        var parent: HTMLView
        var scrollTimer: Timer?
        var lastHtmlContent: String = ""
        var lastFontSize: CGFloat = 0
        var lastFontFamily: String = ""
        var lastFontWeight: String = ""
        var lastTextAlignment: String = ""
        var lastLineSpacing: CGFloat = 0
        var lastMargin: CGFloat = 0
        var lastColorPreset: String = ""
        var progressUpdateTimer: Timer?
        weak var webView: WKWebView?
        var savedScrollPosition: Double?
        
        init(_ parent: HTMLView) {
            self.parent = parent
        }
        
        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            // Restore scroll position after navigation completes
            if let href = parent.chapterHref {
                let savedPosition = UserDefaults.standard.double(forKey: "scrollPosition_\(href)")
                if savedPosition > 0.01 {
                    let script = "window.scrollTo(0, document.documentElement.scrollHeight * \(savedPosition));"
                    webView.evaluateJavaScript(script, completionHandler: { _, error in
                        if let error = error {
                            Logger.shared.log("Error restoring scroll position after navigation: \(error)", type: "Error")
                        } else {
                            Logger.shared.log("Restored scroll position to \(savedPosition) after navigation", type: "Debug")
                        }
                    })
                }
            }
            
            // Start tracking progress after navigation completes
            startProgressTracking(webView: webView)
        }
        
        // Handle scroll events from JavaScript
        func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
            if message.name == "scrollHandler", let webView = self.webView {
                // Update reading progress when scroll events are received
                updateReadingProgress(webView: webView)
            }
        }
        
        func startAutoScroll(webView: WKWebView) {
            stopAutoScroll()
            
            scrollTimer = Timer.scheduledTimer(withTimeInterval: 0.016, repeats: true) { _ in // 60fps for smoother scrolling
                let scrollAmount = self.parent.autoScrollSpeed * 0.5 // Reduced increment for smoother scrolling
                
                webView.evaluateJavaScript("window.scrollBy(0, \(scrollAmount));") { _, error in
                    if let error = error {
                        print("Scroll error: \(error)")
                    }
                }
                
                webView.evaluateJavaScript("(window.pageYOffset + window.innerHeight) >= document.body.scrollHeight") { result, _ in
                    if let isAtBottom = result as? Bool, isAtBottom {
                        DispatchQueue.main.async {
                            self.parent.isAutoScrolling = false
                        }
                    }
                }
            }
        }
        
        func stopAutoScroll() {
            scrollTimer?.invalidate()
            scrollTimer = nil
        }
        
        func startProgressTracking(webView: WKWebView) {
            stopProgressTracking()
            
            // Update immediately on start
            updateReadingProgress(webView: webView)
            
            // Then set up a timer for periodic updates - use a weaker timer that won't fire when the app is in the background
            progressUpdateTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self, weak webView] _ in
                // Only update if webView is still valid (view is still visible)
                guard let strongSelf = self, let webView = webView, webView.window != nil else {
                    // If webView is no longer in window hierarchy, stop tracking
                    self?.stopProgressTracking()
                    return
                }
                strongSelf.updateReadingProgress(webView: webView)
            }
            
            // Also track scroll events for more responsive updates
            let script = """
            document.addEventListener('scroll', function() {
                window.webkit.messageHandlers.scrollHandler.postMessage('scroll');
            }, { passive: true });
            """
            
            // Add a user script to track scroll events
            let userScript = WKUserScript(source: script, injectionTime: .atDocumentEnd, forMainFrameOnly: true)
            webView.configuration.userContentController.addUserScript(userScript)
            
            // Add a message handler for scroll events
            webView.configuration.userContentController.add(self, name: "scrollHandler")
        }
        
        func stopProgressTracking() {
            progressUpdateTimer?.invalidate()
            progressUpdateTimer = nil
            
            // Clean up message handlers
            if let webView = self.webView {
                webView.configuration.userContentController.removeAllUserScripts()
                webView.configuration.userContentController.removeScriptMessageHandler(forName: "scrollHandler")
            }
        }
        
        func updateReadingProgress(webView: WKWebView) {
            // Check if webView is actually visible in the window hierarchy
            guard webView.window != nil else {
                // WebView is not visible, stop tracking
                stopProgressTracking()
                return
            }
            
            let script = """
            (function() {
                var scrollHeight = document.documentElement.scrollHeight;
                var scrollTop = window.pageYOffset || document.documentElement.scrollTop;
                var clientHeight = document.documentElement.clientHeight;
                
                // Calculate progress as a percentage
                var rawProgress = scrollHeight > 0 ? (scrollTop + clientHeight) / scrollHeight : 0;
                
                // If we're very close to the bottom (within 5%), consider it complete
                var progress = rawProgress > 0.95 ? 1.0 : rawProgress;
                
                return {
                    scrollHeight: scrollHeight,
                    scrollTop: scrollTop,
                    clientHeight: clientHeight,
                    progress: progress,
                    isAtBottom: (scrollTop + clientHeight >= scrollHeight - 10),
                    scrollPosition: scrollTop / scrollHeight
                };
            })();
            """
            
            webView.evaluateJavaScript(script) { [weak self] result, error in
                guard let self = self, let dict = result as? [String: Any],
                      let progress = dict["progress"] as? Double else {
                    return
                }
                
                // Save the scroll position for reopening
                if let scrollPosition = dict["scrollPosition"] as? Double {
                    self.savedScrollPosition = scrollPosition
                    
                    // Save the scroll position to UserDefaults
                    if let href = self.parent.chapterHref {
                        UserDefaults.standard.set(scrollPosition, forKey: "scrollPosition_\(href)")
                    }
                }
                
                // Log the progress for debugging
                if let isAtBottom = dict["isAtBottom"] as? Bool, isAtBottom {
                    Logger.shared.log("Reader at bottom of page, setting progress to 100%", type: "Debug")
                    self.parent.onProgressChanged?(1.0)
                } else {
                    self.parent.onProgressChanged?(progress)
                }
            }
        }
    }

    func makeUIView(context: Context) -> WKWebView {
        let webView = WKWebView()
        webView.backgroundColor = .clear
        webView.isOpaque = false
        webView.scrollView.backgroundColor = .clear
        
        webView.scrollView.showsHorizontalScrollIndicator = false
        webView.scrollView.bounces = false
        webView.scrollView.alwaysBounceHorizontal = false
        webView.scrollView.contentInsetAdjustmentBehavior = .never
        webView.navigationDelegate = context.coordinator
        
        // Store the webView reference in the coordinator for later use
        context.coordinator.webView = webView
        
        return webView
    }
    
    func updateUIView(_ webView: WKWebView, context: Context) {
        let coordinator = context.coordinator
        
        if isAutoScrolling {
            coordinator.startAutoScroll(webView: webView)
        } else {
            coordinator.stopAutoScroll()
        }
        
        // Only track reading progress when the view is active
        if webView.window != nil {
            coordinator.startProgressTracking(webView: webView)
        } else {
            coordinator.stopProgressTracking()
        }
        
        guard !htmlContent.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return
        }
        
        let contentChanged = coordinator.lastHtmlContent != htmlContent
        let fontSizeChanged = coordinator.lastFontSize != fontSize
        let fontFamilyChanged = coordinator.lastFontFamily != fontFamily
        let fontWeightChanged = coordinator.lastFontWeight != fontWeight
        let alignmentChanged = coordinator.lastTextAlignment != textAlignment
        let lineSpacingChanged = coordinator.lastLineSpacing != lineSpacing
        let marginChanged = coordinator.lastMargin != margin
        let colorChanged = coordinator.lastColorPreset != colorPreset.name
        
        if contentChanged || fontSizeChanged || fontFamilyChanged || fontWeightChanged ||
           alignmentChanged || lineSpacingChanged || marginChanged || colorChanged {
            let htmlTemplate = """
            <!DOCTYPE html>
            <html>
            <head>
                <meta name="viewport" content="width=device-width, initial-scale=1.0, user-scalable=no">
                <style>
                    html, body {
                        font-family: \(fontFamily), system-ui;
                        font-size: \(fontSize)px;
                        font-weight: \(fontWeight);
                        line-height: \(lineSpacing);
                        text-align: \(textAlignment);
                        padding: \(margin)px;
                        margin: 0;
                        color: \(colorPreset.text);
                        background-color: \(colorPreset.background);
                        transition: all 0.3s ease;
                        overflow-x: hidden;
                        width: 100%;
                        max-width: 100%;
                        word-wrap: break-word;
                        -webkit-user-select: text;
                        -webkit-touch-callout: none;
                        -webkit-tap-highlight-color: transparent;
                    }
                    body {
                        box-sizing: border-box;
                    }
                    p, div, span, h1, h2, h3, h4, h5, h6 {
                        font-size: inherit;
                        font-family: inherit;
                        font-weight: inherit;
                        line-height: inherit;
                        text-align: inherit;
                        color: inherit;
                        max-width: 100%;
                        word-wrap: break-word;
                        overflow-wrap: break-word;
                    }
                    * {
                        max-width: 100%;
                        box-sizing: border-box;
                    }
                </style>
            </head>
            <body>
                \(htmlContent)
            </body>
            </html>
            """
            
            Logger.shared.log("Loading HTML content into WebView", type: "Debug")
            webView.loadHTMLString(htmlTemplate, baseURL: nil)
            
            // Restore scroll position after the content loads
            if let href = chapterHref {
                let savedPosition = UserDefaults.standard.double(forKey: "scrollPosition_\(href)")
                if savedPosition > 0.01 {
                    // Wait for the content to load before scrolling
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        let script = "window.scrollTo(0, document.documentElement.scrollHeight * \(savedPosition));"
                        webView.evaluateJavaScript(script, completionHandler: { _, error in
                            if let error = error {
                                Logger.shared.log("Error restoring scroll position: \(error)", type: "Error")
                            } else {
                                Logger.shared.log("Restored scroll position to \(savedPosition)", type: "Debug")
                            }
                        })
                    }
                }
            }
            
            coordinator.lastHtmlContent = htmlContent
            coordinator.lastFontSize = fontSize
            coordinator.lastFontFamily = fontFamily
            coordinator.lastFontWeight = fontWeight
            coordinator.lastTextAlignment = textAlignment
            coordinator.lastLineSpacing = lineSpacing
            coordinator.lastMargin = margin
            coordinator.lastColorPreset = colorPreset.name
        }
    }
}
