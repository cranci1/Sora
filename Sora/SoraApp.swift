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
    
    // Hardcoded accent color bound to the theme
    private var dynamicAccentColor: Color {
        // If appearance is light, return black, if dark, return white.
        if settings.selectedAppearance == .dark {
            return .white
        } else {
            return .black
        }
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(moduleManager)
                .environmentObject(settings)
                .environmentObject(librarykManager)
                .accentColor(dynamicAccentColor)
                .onAppear {
                    settings.updateAppearance()
                    if UserDefaults.standard.bool(forKey: "refreshModulesOnLaunch") {
                        Task {
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
        
        AniListToken.exchangeAuthorizationCodeForToken(code: code) { success in
            if success {
                Logger.shared.log("Token exchange successful")
            } else {
                Logger.shared.log("Token exchange failed", type: "Error")
            }
        }
    }
}
