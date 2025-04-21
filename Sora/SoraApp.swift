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
    @StateObject private var profileStore = ProfileStore()
    @StateObject private var libraryManager = LibraryManager()
    @StateObject private var continueWatchingManager = ContinueWatchingManager()

    init() {
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
                .environmentObject(libraryManager)
                .environmentObject(continueWatchingManager)
                .environmentObject(profileStore)
                .accentColor(settings.accentColor)
                .onAppear {
                    // pass initial profile value to other manager
                    let suite = self.profileStore.getUserDefaultsSuite()
                    self.libraryManager.userDefaultsSuite = suite
                    self.continueWatchingManager.userDefaultsSuite = suite

                    _ = iCloudSyncManager.shared

                    settings.updateAppearance()
                    iCloudSyncManager.shared.syncModulesFromiCloud()
                    Task {
                        if UserDefaults.standard.bool(forKey: "refreshModulesOnLaunch") {
                            await moduleManager.refreshModules()
                        }
                    }
                }
                .onOpenURL { url in
                    if let params = url.queryParameters, params["code"] != nil {
                        Self.handleRedirect(url: url)
                    } else {
                        handleURL(url)
                    }
                }
                .onChange(of: profileStore.currentProfile) { _ in
                    // pass changed suite value to other manager
                    let suite = self.profileStore.getUserDefaultsSuite()
                    libraryManager.updateProfileSuite(suite)
                    continueWatchingManager.updateProfileSuite(suite)
                }
        }
    }
    
    private func handleURL(_ url: URL) {
        guard url.scheme == "sora",
              url.host == "module",
              let components = URLComponents(url: url, resolvingAgainstBaseURL: true),
              let moduleURL = components.queryItems?.first(where: { $0.name == "url" })?.value else {
                  return
              }
        
        let addModuleView = ModuleAdditionSettingsView(moduleUrl: moduleURL).environmentObject(moduleManager)
        let hostingController = UIHostingController(rootView: addModuleView)
        
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let window = windowScene.windows.first {
            window.rootViewController?.present(hostingController, animated: true)
        } else {
            Logger.shared.log("Failed to present module addition view: No window scene found", type: "Error")
        }
    }
    
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
