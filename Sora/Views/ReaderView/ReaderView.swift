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
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var tabBarController: TabBarController
    
    var body: some View {
        ZStack {
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
                HTMLView(htmlContent: htmlContent)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .padding(.horizontal)
                    .ignoresSafeArea(.container, edges: .vertical)
            }
        }
        .navigationTitle(chapterTitle)
        .navigationBarTitleDisplayMode(.inline)
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

#Preview {
    NavigationView {
        ReaderView(
            moduleId: "test",
            chapterHref: "example.com/chapter1",
            chapterTitle: "Chapter 1: The Beginning"
        )
    }
} 