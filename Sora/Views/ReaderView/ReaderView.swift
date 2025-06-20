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
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var tabBarController: TabBarController
    
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
                    HTMLView(htmlContent: htmlContent)
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
                    }
                }
            }
            
            headerView
                .opacity(isHeaderVisible ? 1 : 0)
                .offset(y: isHeaderVisible ? 0 : -100)
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
                        .background(Color.gray.opacity(0.2))
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
}

struct HTMLView: UIViewRepresentable {
    let htmlContent: String

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
                    font-family: -apple-system, system-ui;
                    line-height: 1.6;
                    padding: 0;
                    margin: 0;
                    color: var(--text-color);
                    background-color: transparent;
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
