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
        }
    }

    private func handleURL(_ url: URL) {
        guard url.scheme == "sora", let host = url.host else { return }
        switch host {
        case "default_page":
            if let comps = URLComponents(url: url, resolvingAgainstBaseURL: true),
               let libraryURL = comps.queryItems?.first(where: { $0.name == "url" })?.value {
                
                UserDefaults.standard.set(libraryURL, forKey: "lastCommunityURL")
                UserDefaults.standard.set(true, forKey: "didReceiveDefaultPageLink")

                let communityView = CommunityLibraryView()
                                    .environmentObject(moduleManager)
                let hostingController = UIHostingController(rootView: communityView)
                DispatchQueue.main.async {
                    if let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                       let window = scene.windows.first,
                       let root = window.rootViewController {
                        root.present(hostingController, animated: true) {
                            DropManager.shared.showDrop(
                                title: "Module Library Added",
                                subtitle: "You can browse the community library in settings.",
                                duration: 2,
                                icon: UIImage(systemName: "books.vertical.circle.fill")
                            )
                        }
                    }
                }
            }
            
        case "module":
            guard url.scheme == "sora",
                  url.host == "module",
                  let components = URLComponents(url: url, resolvingAgainstBaseURL: true),
                  let moduleURL = components.queryItems?.first(where: { $0.name == "url" })?.value
            else {
                return
            }

            let addModuleView = ModuleAdditionSettingsView(moduleUrl: moduleURL)
                .environmentObject(moduleManager)
            let hostingController = UIHostingController(rootView: addModuleView)

            if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
               let window = windowScene.windows.first {
                window.rootViewController?.present(hostingController, animated: true)
            } else {
                Logger.shared.log(
                    "Failed to present module addition view: No window scene found",
                    type: "Error"
                )
            }

        default:
            break
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
