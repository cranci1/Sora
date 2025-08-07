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
    @StateObject private var libraryManager = LibraryManager()
    @StateObject private var downloadManager = DownloadManager()
    @StateObject private var jsController = JSController.shared
    
    init() {
        if let userAccentColor = UserDefaults.standard.color(forKey: "accentColor") {
            UIView.appearance(whenContainedInInstancesOf: [UIAlertController.self]).tintColor = userAccentColor
        }
    }
    
    var body: some Scene {
        WindowGroup {
            Group {
                if !UserDefaults.standard.bool(forKey: "hideSplashScreen") {
                    SplashScreenView()
                } else {
                    ContentView()
                }
            }
            .environment(\.layoutDirection, .leftToRight)
            .environmentObject(moduleManager)
            .environmentObject(settings)
            .environmentObject(libraryManager)
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
                
                _ = LocalizationManager.shared
                
                if let languages = UserDefaults.standard.object(forKey: "AppleLanguages") as? [String],
                   let primaryLanguage = languages.first,
                   primaryLanguage == "mn" || primaryLanguage == "mn-Cyrl" {
                    Logger.shared.log("App initialized with Mongolian language: \(primaryLanguage)", type: "Debug")
                    
                    if let path = Bundle.main.path(forResource: "mn", ofType: "lproj"),
                       let bundle = Bundle(path: path) {
                        let testKey = "About"
                        let testString = bundle.localizedString(forKey: testKey, value: nil, table: nil)
                        Logger.shared.log("Test Mongolian string for '\(testKey)': \(testString)", type: "Debug")
                    } else {
                        Logger.shared.log("Failed to load Mongolian bundle", type: "Error")
                    }
                }
                
                Task {
                    await Self.clearTmpFolder()
                    await MainActor.run {
                        jsController.initializeDownloadSession()
                    }
                    
                    TraktToken.checkAuthenticationStatus { isAuthenticated in
                        if isAuthenticated {
                            Logger.shared.log("Trakt authentication is valid", type: "Debug")
                        } else {
                            Logger.shared.log("Trakt authentication required", type: "Debug")
                        }
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
    
    private static func clearTmpFolder() async {
        let fileManager = FileManager.default
        let tmpDirectory = NSTemporaryDirectory()
        
        do {
            let tmpURL = URL(fileURLWithPath: tmpDirectory)
            let tmpContents = try fileManager.contentsOfDirectory(at: tmpURL, includingPropertiesForKeys: nil)
            
            try await withThrowingTaskGroup(of: Void.self) { group in
                for url in tmpContents {
                    group.addTask {
                        try FileManager.default.removeItem(at: url)
                    }
                }
                try await group.waitForAll()
            }
        } catch {
            Logger.shared.log("Failed to clear tmp folder: \(error.localizedDescription)", type: "Error")
        }
    }
}
