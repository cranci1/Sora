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
    
    var body: some View {
        ZStack {
            Color(UIColor.systemBackground).ignoresSafeArea()
            
            if isLoading {
                ProgressView()
            } else if let error = error {
                VStack {
                    Text("Error loading chapter")
                        .font(.headline)
                    Text(error.localizedDescription)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            } else {
                ZStack {
                    HTMLView(
                        htmlContent: htmlContent,
                        fontSize: fontSize,
                        fontFamily: selectedFont,
                        fontWeight: fontWeight
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
    
    private var headerView: some View {
        VStack {
            HStack {
                Button(action: {
                    dismiss()
                }) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(.primary)
                        .padding(12)
                        .background(Color(UIColor.secondarySystemBackground))
                        .clipShape(Circle())
                        .circularGradientOutline()
                }
                .padding(.leading)
                
                Text(chapterTitle)
                    .font(.headline)
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
                    // Font size control with context menu slider
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
                            .foregroundColor(.primary)
                            .padding(12)
                            .background(Color(UIColor.secondarySystemBackground))
                            .clipShape(Circle())
                            .circularGradientOutline()
                    }
                    
                    // Font family control with context menu
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
                        Image(systemName: "textformat")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(.primary)
                            .padding(12)
                            .background(Color(UIColor.secondarySystemBackground))
                            .clipShape(Circle())
                            .circularGradientOutline()
                    }
                    
                    // Font weight control with context menu
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
                            .foregroundColor(.primary)
                            .padding(12)
                            .background(Color(UIColor.secondarySystemBackground))
                            .clipShape(Circle())
                            .circularGradientOutline()
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

struct HTMLView: UIViewRepresentable {
    let htmlContent: String
    let fontSize: CGFloat
    let fontFamily: String
    let fontWeight: String

    func makeUIView(context: Context) -> WKWebView {
        let webView = WKWebView()
        webView.backgroundColor = .clear
        webView.isOpaque = false
        webView.scrollView.backgroundColor = .clear

        return webView
    }
    
    func updateUIView(_ webView: WKWebView, context: Context) {
        guard !htmlContent.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return
        }
        
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
                    color: var(--text-color);
                    background-color: transparent;
                    transition: all 0.3s ease;
                }
                p, div, span, h1, h2, h3, h4, h5, h6 {
                    font-size: inherit;
                    font-family: inherit;
                    font-weight: inherit;
                    line-height: inherit;
                }
                @media (prefers-color-scheme: dark) {
                    :root {
                        --text-color: #FFFFFF;
                    }
                }
                @media (prefers-color-scheme: light) {
                    :root {
                        --text-color: #000000;
                    }
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
    }
}
