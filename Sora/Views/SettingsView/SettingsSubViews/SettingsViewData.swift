//
//  SettingsViewData.swift
//  Sora
//
//  Created by Francesco on 05/02/25.
//

import SwiftUI

struct SettingsViewData: View {
    @State private var showEraseAppDataAlert = false
    @State private var showRemoveDocumentsAlert = false
    @State private var showSizeAlert = false
    
    var body: some View {
        Form {
            Section(header: Text("App storage"), footer: Text("The caches used by Sora are stored images that help load content faster\n\nThe App Data should never be erased if you dont know what that will cause.\n\nClearing the documents folder will remove all the modules and downloads")) {
                Button(action: clearCache) {
                    Text("Clear Cache")
                }
                
                Button(action: {
                    showEraseAppDataAlert = true
                }) {
                    Text("Erase all App Data")
                }
                .alert(isPresented: $showEraseAppDataAlert) {
                    Alert(
                        title: Text("Confirm Erase App Data"),
                        message: Text("Are you sure you want to erase all app data? This action cannot be undone. (The app will then close)"),
                        primaryButton: .destructive(Text("Erase")) {
                            eraseAppData()
                        },
                        secondaryButton: .cancel()
                    )
                }
                
                Button(action: {
                    showRemoveDocumentsAlert = true
                }) {
                    Text("Remove All Files in Documents")
                }
                .alert(isPresented: $showRemoveDocumentsAlert) {
                    Alert(
                        title: Text("Confirm Remove All Files"),
                        message: Text("Are you sure you want to remove all files in the documents folder? This will also remove all modules and you will lose the favorite items. This action cannot be undone. (The app will then close)"),
                        primaryButton: .destructive(Text("Remove")) {
                            removeAllFilesInDocuments()
                        },
                        secondaryButton: .cancel()
                    )
                }
            }
        }
        .navigationTitle("App Data")
        .navigationViewStyle(StackNavigationViewStyle())
    }
    
    func eraseAppData() {
        if let domain = Bundle.main.bundleIdentifier {
            UserDefaults.standard.removePersistentDomain(forName: domain)
            UserDefaults.standard.synchronize()
            Logger.shared.log("Cleared app data!", type: "General")
            exit(0)
        }
    }
    
    func clearCache() {
        let cacheURL = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first
        
        do {
            if let cacheURL = cacheURL {
                let filePaths = try FileManager.default.contentsOfDirectory(at: cacheURL, includingPropertiesForKeys: nil, options: [])
                for filePath in filePaths {
                    try FileManager.default.removeItem(at: filePath)
                }
                Logger.shared.log("Cache cleared successfully!", type: "General")
            }
        } catch {
            Logger.shared.log("Failed to clear cache.", type: "Error")
        }
    }
    
    func removeAllFilesInDocuments() {
        let fileManager = FileManager.default
        if let documentsURL = fileManager.urls(for: .cachesDirectory, in: .userDomainMask).first {
            do {
                let fileURLs = try fileManager.contentsOfDirectory(at: documentsURL, includingPropertiesForKeys: nil)
                for fileURL in fileURLs {
                    try fileManager.removeItem(at: fileURL)
                }
                Logger.shared.log("All files in documents folder removed", type: "General")
                exit(0)
            } catch {
                Logger.shared.log("Error removing files in documents folder: \(error)", type: "Error")
            }
        }
    }
}
