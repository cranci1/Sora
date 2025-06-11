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
    @StateObject private var downloadManager = DownloadManager()
    @StateObject private var jsController = JSController.shared
    
    init() {
        if let userAccentColor = UserDefaults.standard.color(forKey: "accentColor") {
            UIView.appearance(whenContainedInInstancesOf: [UIAlertController.self]).tintColor = userAccentColor
        }
        
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
            Group {
                if !UserDefaults.standard.bool(forKey: "hideSplashScreenEnable") {
                    SplashScreenView()
                } else {
                    ContentView()
                }
            }
            .environmentObject(moduleManager)
            .environmentObject(settings)
            .environmentObject(librarykManager)
            .environmentObject(downloadManager)
            .environmentObject(jsController)
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
                handleURL(url)
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
                
                DropManager.shared.showDrop(
                    title: "Module Library Added",
                    subtitle: "You can browse the community library in settings.",
                    duration: 2,
                    icon: UIImage(systemName: "books.vertical.circle.fill")
                )
            }
            
        case "module":
            guard url.scheme == "sora",
                  url.host == "module",
                  let components = URLComponents(url: url, resolvingAgainstBaseURL: true),
                  let moduleURL = components.queryItems?.first(where: { $0.name == "url" })?.value
            else {
                return
            }
            
            let addModuleView = ModuleAdditionSettingsView(moduleUrl: moduleURL).environmentObject(moduleManager)
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
}

@objc class AppInfo: NSObject {
    @objc static let shared = AppInfo()
    
    @objc func getBundleIdentifier() -> String {
        return Bundle.main.bundleIdentifier ?? "me.cranci.sulfur"
    }
    
    @objc func getDisplayName() -> String {
        return Bundle.main.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String ?? Bundle.main.object(forInfoDictionaryKey: "CFBundleName") as! String
    }
    
    @objc func isValidApp() -> Bool {
        let bundleId = getBundleIdentifier().lowercased()
        let displayName = getDisplayName().lowercased()
        
        let hasValidBundleId = bundleId.contains("sulfur")
        let hasValidDisplayName = displayName == "sora" || displayName == "sulfur"
        
        return hasValidBundleId && hasValidDisplayName
    }
}
