//
//  ReaderView.swift
//  Sora
//
//  Created by paul on 18/06/25.
//

import SwiftUI
import WebKit

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
    
    private let colorPresets = [
        (name: "Pure", background: "#ffffff", text: "#000000"),
        (name: "Warm", background: "#f9f1e4", text: "#000000"),
        (name: "Slate", background: "#49494d", text: "#ffffff"),
        (name: "Dark", background: "#000000", text: "#ffffff")
    ]
    
    // Computed property to get current theme colors
    private var currentTheme: (background: Color, text: Color) {
        let preset = colorPresets[selectedColorPreset]
        return (
            background: Color(hex: preset.background),
            text: Color(hex: preset.text)
        )
    }
    
    var body: some View {
        ZStack {
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
                    HTMLView(
                        htmlContent: htmlContent,
                        fontSize: fontSize,
                        fontFamily: selectedFont,
                        fontWeight: fontWeight,
                        isAutoScrolling: $isAutoScrolling,
                        autoScrollSpeed: autoScrollSpeed,
                        colorPreset: colorPresets[selectedColorPreset]
                    )
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .padding(.horizontal)
                    
                    VStack {
                        Rectangle()
                            .fill(Color.clear)
                            .frame(height: 150)
                            .contentShape(Rectangle())
                            .onTapGesture {
                                withAnimation(.easeInOut(duration: 0.6)) {
                                    isHeaderVisible.toggle()
                                }
                            }
                        Spacer()
                        Rectangle()
                            .fill(Color.clear)
                            .frame(height: 120)
                            .contentShape(Rectangle())
                            .onTapGesture {
                                withAnimation(.easeInOut(duration: 0.6)) {
                                    isHeaderVisible.toggle()
                                }
                            }
                    }
                }
            }
            
            headerView
                .opacity(isHeaderVisible ? 1 : 0)
                .offset(y: isHeaderVisible ? 0 : -100)
                .allowsHitTesting(isHeaderVisible)
                .animation(.easeInOut(duration: 0.6), value: isHeaderVisible)
            
            footerView
                .opacity(isHeaderVisible ? 1 : 0)
                .offset(y: isHeaderVisible ? 0 : 100)
                .allowsHitTesting(isHeaderVisible)
                .animation(.easeInOut(duration: 0.6), value: isHeaderVisible)
        }
        .navigationBarHidden(true)
        .navigationBarBackButtonHidden(true)
        .ignoresSafeArea()
        .onAppear {
            tabBarController.hideTabBar()
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
            }
            .padding(.top, (UIApplication.shared.windows.first?.safeAreaInsets.top ?? 0))
            .padding(.bottom, 30)
            .background(ProgressiveBlurView())
            .onTapGesture {
                withAnimation(.easeInOut(duration: 0.6)) {
                    isHeaderVisible = false
                }
            }
            
            Spacer()
        }
        .ignoresSafeArea()
    }
    
    private var footerView: some View {
        VStack {
            Spacer()
            
            VStack {
                HStack(spacing: 20) {
                    Menu {
                        VStack {
                            Text("Font Size: \(Int(fontSize))pt")
                                .font(.headline)
                                .padding(.bottom, 8)
                            
                            Slider(value: $fontSize, in: 12...32, step: 1) {
                                Text("Font Size")
                            }
                            .padding(.horizontal)
                        }
                        .padding()
                    } label: {
                        Image(systemName: "textformat.size")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(currentTheme.text)
                            .padding(12)
                            .background(currentTheme.background.opacity(0.8))
                            .clipShape(Circle())
                            .circularGradientOutline()
                    }
                    
                    Menu {
                        ForEach(fontOptions, id: \.0) { font in
                            Button(action: {
                                selectedFont = font.0
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
                        Image(systemName: "textformat.characters")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(currentTheme.text)
                            .padding(12)
                            .background(currentTheme.background.opacity(0.8))
                            .clipShape(Circle())
                            .circularGradientOutline()
                    }
                    
                    Menu {
                        ForEach(weightOptions, id: \.0) { weight in
                            Button(action: {
                                fontWeight = weight.0
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
                        Image(systemName: "bold")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(currentTheme.text)
                            .padding(12)
                            .background(currentTheme.background.opacity(0.8))
                            .clipShape(Circle())
                            .circularGradientOutline()
                    }
                    
                    Menu {
                        ForEach(0..<colorPresets.count, id: \.self) { index in
                            Button(action: {
                                selectedColorPreset = index
                            }) {
                                HStack {
                                    ColorPreviewCircle(
                                        backgroundColor: colorPresets[index].background,
                                        textColor: colorPresets[index].text
                                    )
                                    .frame(width: 20, height: 20)
                                    
                                    Text(colorPresets[index].name)
                                    
                                    Spacer()
                                    
                                    if selectedColorPreset == index {
                                        Image(systemName: "checkmark")
                                            .foregroundColor(.blue)
                                    }
                                }
                            }
                        }
                    } label: {
                        Image(systemName: "paintpalette")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(currentTheme.text)
                            .padding(12)
                            .background(currentTheme.background.opacity(0.8))
                            .clipShape(Circle())
                            .circularGradientOutline()
                    }
                    
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
                .padding(.top, 20)
                .padding(.bottom, (UIApplication.shared.windows.first?.safeAreaInsets.bottom ?? 0) + 20)
            }
            .frame(maxWidth: .infinity)
            .background(ProgressiveBlurView())
            .onTapGesture {
                withAnimation(.easeInOut(duration: 0.6)) {
                    isHeaderVisible = false
                }
            }
        }
        .ignoresSafeArea()
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
        var lastColorPreset: String = ""
        
        init(_ parent: HTMLView) {
            self.parent = parent
        }
        
        func startAutoScroll(webView: WKWebView) {
            stopAutoScroll()
            
            scrollTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { _ in
                let scrollAmount = self.parent.autoScrollSpeed * 2.0 // Adjust scroll increment
                
                webView.evaluateJavaScript("window.scrollBy(0, \(scrollAmount));") { _, error in
                    if let error = error {
                        print("Scroll error: \(error)")
                    }
                }
                
                // Check if we've reached the bottom
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
        
        return webView
    }
    
    func updateUIView(_ webView: WKWebView, context: Context) {
        let coordinator = context.coordinator
        
        // Handle auto scroll state changes
        if isAutoScrolling {
            coordinator.startAutoScroll(webView: webView)
        } else {
            coordinator.stopAutoScroll()
        }
        
        guard !htmlContent.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return
        }
        
        // Only reload HTML if content or styling has actually changed
        let contentChanged = coordinator.lastHtmlContent != htmlContent
        let fontSizeChanged = coordinator.lastFontSize != fontSize
        let fontFamilyChanged = coordinator.lastFontFamily != fontFamily
        let fontWeightChanged = coordinator.lastFontWeight != fontWeight
        let colorChanged = coordinator.lastColorPreset != colorPreset.name
        
        if contentChanged || fontSizeChanged || fontFamilyChanged || fontWeightChanged || colorChanged {
            let htmlTemplate = """
            <!DOCTYPE html>
            <html>
            <head>
                <meta name="viewport" content="width=device-width, initial-scale=1.0">
                <style>
                    body {
                        font-family: \(fontFamily), system-ui;
                        font-size: \(fontSize)px;
                        font-weight: \(fontWeight);
                        line-height: 1.6;
                        padding: 0;
                        margin: 0;
                        color: \(colorPreset.text);
                        background-color: \(colorPreset.background);
                        transition: all 0.3s ease;
                    }
                    p, div, span, h1, h2, h3, h4, h5, h6 {
                        font-size: inherit;
                        font-family: inherit;
                        font-weight: inherit;
                        line-height: inherit;
                        color: inherit;
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
            
            // Update the cached values
            coordinator.lastHtmlContent = htmlContent
            coordinator.lastFontSize = fontSize
            coordinator.lastFontFamily = fontFamily
            coordinator.lastFontWeight = fontWeight
            coordinator.lastColorPreset = colorPreset.name
        }
    }
}
