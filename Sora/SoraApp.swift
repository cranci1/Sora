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
    @State private var moduleUrl: String?
    @State private var showModuleAdditionView = false

    var body: some Scene {
        WindowGroup {
            ZStack {
                ContentView()
                    .environmentObject(moduleManager)
                    .environmentObject(settings)
                    .environmentObject(libraryManager)
                    .accentColor(settings.accentColor)
                    .onAppear {
                        settings.updateAppearance()
                        if UserDefaults.standard.bool(forKey: "refreshModulesOnLaunch") {
                            Task {
                                await moduleManager.refreshModules()
                            }
                        }
                    }
                    .onOpenURL { url in
                        handleURL(url)
                    }
            }
            .sheet(isPresented: $showModuleAdditionView) {
                ModuleAdditionSettingsView(moduleUrl: moduleUrl ?? "")
            }
            .onChange(of: moduleUrl) { newValue in
                if let newValue = newValue {
                    Logger.shared.log("Using URL: \(newValue)", type: "General") // Log the URL when it changes
                }
            }
        }
    }

    private func handleURL(_ url: URL) {
        guard url.scheme == "sora",
              url.host == "module",
              let components = URLComponents(url: url, resolvingAgainstBaseURL: true),
              let moduleURL = components.queryItems?.first(where: { $0.name == "url" })?.value else {
              Logger.shared.log("Failed to parse URL: \(url)", type: "General")
                  return
              }

        DispatchQueue.main.async {
            Logger.shared.log("Parsed Module URL: \(moduleURL)", type: "General")
            self.moduleUrl = moduleURL
            self.showModuleAdditionView = true
        }
    }
}
