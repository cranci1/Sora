//
//  SoraApp.swift
//  Sora
//
//  Created by Francesco on 06/01/25.
//

import SwiftUI

@main
struct SoraApp: App {
    @StateObject private var settings = Settings()
    @StateObject private var moduleManager = ModuleManager()
    @StateObject private var librarykManager = LibraryManager()

    init() {
        _ = iCloudSyncManager.shared

        TraktToken.checkAuthenticationStatus { isAuthenticated in
            if isAuthenticated {
                Logger.shared.log("Trakt authentication is valid")
            } else {
                Logger.shared.log("Trakt authentication required", type: "Error")
            }
        }
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(moduleManager)
                .environmentObject(settings)
                .environmentObject(librarykManager)
                .accentColor(settings.accentColor)
                .onAppear {
                    settings.updateAppearance()
                    iCloudSyncManager.shared.syncModulesFromiCloud()
                    Task {
                        if UserDefaults.standard.bool(forKey: "refreshModulesOnLaunch") {
                            await moduleManager.refreshModules()
                        }
                    }
                }
                .onOpenURL { url in
                    // Route codex and module deep links
                    if let params = url.queryParameters, params["code"] != nil {
                        Self.handleRedirect(url: url)
                    } else {
                        handleURL(url)
                    }
                }
        }
    }

    /// Handle custom sora:// links for community or module
    private func handleURL(_ url: URL) {
        guard url.scheme == "sora", let host = url.host else { return }
        switch host {
        case "default_page":
            if let comps = URLComponents(url: url, resolvingAgainstBaseURL: true),
               let libraryURL = comps.queryItems?.first(where: { $0.name == "url" })?.value {
                // Persist last community URL and flag
                UserDefaults.standard.set(libraryURL, forKey: "lastCommunityURL")
                UserDefaults.standard.set(true, forKey: "didReceiveDefaultPageLink")
                // Present community browser
                let add = CommunityLibraryView()
                    .environmentObject(moduleManager)
                let host = UIHostingController(rootView: add)
                if let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                   let window = scene.windows.first,
                   let root = window.rootViewController {
                    root.present(host, animated: true)
                }
            }

        case "module":
            if let comps = URLComponents(url: url, resolvingAgainstBaseURL: true),
               let moduleURL = comps.queryItems?.first(where: { $0.name == "url" })?.value {
                // Present module addition UI
                let add = ModuleAdditionSettingsView(moduleUrl: moduleURL)
                    .environmentObject(moduleManager)
                let host = UIHostingController(rootView: add)
                if let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                   let window = scene.windows.first,
                   let root = window.rootViewController {
                    root.present(host, animated: true)
                }
            }

        default:
            break
        }
    }

    /// OAuth redirect handler for code flows
    static func handleRedirect(url: URL) {
        guard let params = url.queryParameters,
              let code = params["code"] else {
            Logger.shared.log("Failed to extract authorization code")
            return
        }

        switch url.host {
        case "anilist":
            AniListToken.exchangeAuthorizationCodeForToken(code: code) { success in
                if success {
                    Logger.shared.log("AniList token exchange successful")
                } else {
                    Logger.shared.log("AniList token exchange failed", type: "Error")
                }
            }

        case "trakt":
            TraktToken.exchangeAuthorizationCodeForToken(code: code) { success in
                if success {
                    Logger.shared.log("Trakt token exchange successful")
                } else {
                    Logger.shared.log("Trakt token exchange failed", type: "Error")
                }
            }

        default:
            Logger.shared.log("Unknown authentication service", type: "Error")
        }
    }
}
