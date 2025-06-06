//
//  SoraApp.swift
//  Sora
//
//  Created by Francesco on 06/01/25.
//

import SwiftUI
import UIKit

class OrientationManager: ObservableObject {
    static let shared = OrientationManager()
    
    @Published var isLocked = false
    private var lockedOrientation: UIInterfaceOrientationMask = .all
    
    private init() {}
    
    func lockOrientation() {
        let currentOrientation = UIApplication.shared.windows.first?.windowScene?.interfaceOrientation ?? .portrait
        
        switch currentOrientation {
        case .portrait, .portraitUpsideDown:
            lockedOrientation = .portrait
        case .landscapeLeft, .landscapeRight:
            lockedOrientation = .landscape
        default:
            lockedOrientation = .portrait
        }
        
        isLocked = true
        
        UIDevice.current.setValue(currentOrientation.rawValue, forKey: "orientation")
        UIViewController.attemptRotationToDeviceOrientation()
    }
    
    func unlockOrientation(after delay: TimeInterval = 0.0) {
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
            self.isLocked = false
            self.lockedOrientation = .all
            
            UIViewController.attemptRotationToDeviceOrientation()
        }
    }
    
    func supportedOrientations() -> UIInterfaceOrientationMask {
        return isLocked ? lockedOrientation : .all
    }
}

@main
struct SoraApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
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
            ContentView()
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
class AppInfo: NSObject {
    @objc func getBundleIdentifier() -> String {
        return Bundle.main.bundleIdentifier ?? "me.cranci.sulfur"
    }
    
    @objc func getDisplayName() -> String {
        return Bundle.main.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String ?? Bundle.main.object(forInfoDictionaryKey: "CFBundleName") as! String
    }
}

class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication, supportedInterfaceOrientationsFor window: UIWindow?) -> UIInterfaceOrientationMask {
        return OrientationManager.shared.supportedOrientations()
    }
}
