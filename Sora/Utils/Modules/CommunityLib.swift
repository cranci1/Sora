//
//  CommunityLib.swift
//  Sulfur
//
//  Created by seiike on 23/04/2025.
//

import SwiftUI
@preconcurrency import WebKit

private struct ModuleLink: Identifiable {
    let id = UUID()
    let url: String
}

struct CommunityLibraryView: View {
    @EnvironmentObject var moduleManager: ModuleManager

    @AppStorage("lastCommunityURL") private var inputURL: String = ""
    @State private var webURL: URL?
    @State private var errorMessage: String?
    @State private var moduleLinkToAdd: ModuleLink?

    var body: some View {
        VStack(spacing: 0) {
            if let err = errorMessage {
                Text(err)
                    .foregroundColor(.red)
                    .padding(.horizontal)
            }

            WebView(url: webURL) { linkURL in

                if let comps = URLComponents(url: linkURL, resolvingAgainstBaseURL: false),
                   let m = comps.queryItems?.first(where: { $0.name == "url" })?.value {
                    moduleLinkToAdd = ModuleLink(url: m)
                }
            }
            .ignoresSafeArea(edges: .top)
        }
        .onAppear(perform: loadURL)
        .sheet(item: $moduleLinkToAdd) { link in
            ModuleAdditionSettingsView(moduleUrl: link.url)
                .environmentObject(moduleManager)
        }
    }

    private func loadURL() {
        var s = inputURL.trimmingCharacters(in: .whitespacesAndNewlines)
        if !s.hasPrefix("http://") && !s.hasPrefix("https://") {
            s = "https://" + s
        }
        inputURL = s
        if let u = URL(string: s) {
            webURL = u
            errorMessage = nil
        } else {
            webURL = nil
            errorMessage = "Invalid URL"
        }
    }
}

struct WebView: UIViewRepresentable {
    let url: URL?
    let onCustomScheme: (URL) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(onCustom: onCustomScheme)
    }

    func makeUIView(context: Context) -> WKWebView {
        let cfg = WKWebViewConfiguration()
        cfg.preferences.javaScriptEnabled = true
        let wv = WKWebView(frame: .zero, configuration: cfg)
        wv.navigationDelegate = context.coordinator
        return wv
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {
        if let u = url {
            uiView.load(URLRequest(url: u))
        }
    }

    class Coordinator: NSObject, WKNavigationDelegate {
        let onCustom: (URL) -> Void
        init(onCustom: @escaping (URL) -> Void) { self.onCustom = onCustom }

        func webView(_ webView: WKWebView,
                     decidePolicyFor action: WKNavigationAction,
                     decisionHandler: @escaping (WKNavigationActionPolicy) -> Void)
        {
            if let url = action.request.url,
               url.scheme == "sora", url.host == "module"
            {
                onCustom(url)
                decisionHandler(.cancel)
            } else {
                decisionHandler(.allow)
            }
        }
    }
}
