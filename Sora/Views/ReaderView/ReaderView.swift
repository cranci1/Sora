//
//  ReaderView.swift
//  Sora
//
//  Created by paul on 18/06/25.
//

import SwiftUI
import WebKit

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
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var tabBarController: TabBarController
    
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
    
    init(moduleId: String, chapterHref: String, chapterTitle: String) {
        self.moduleId = moduleId
        self.chapterHref = chapterHref
        self.chapterTitle = chapterTitle
        
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
                        colorPreset: colorPresets[selectedColorPreset]
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
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject {
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
        
        init(_ parent: HTMLView) {
            self.parent = parent
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
        
        return webView
    }
    
    func updateUIView(_ webView: WKWebView, context: Context) {
        let coordinator = context.coordinator
        
        if isAutoScrolling {
            coordinator.startAutoScroll(webView: webView)
        } else {
            coordinator.stopAutoScroll()
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
