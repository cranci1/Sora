//
//  SettingsViewData.swift
//  Sora
//
//  Created by Francesco on 05/02/25.
//

import SwiftUI

struct SettingsViewData: View {
    @Environment(\.colorScheme) private var colorScheme

    @State private var showEraseAppDataAlert = false
    @State private var showRemoveDocumentsAlert = false
    @State private var showSizeAlert = false
    
    var body: some View {
        Form {
            Section(header: Text("App Storage")
                        .font(.headline)
                        .foregroundColor(.accentColor),
                     footer: Text("The caches used by Sora are stored images that help load content faster.\n\nThe App Data should never be erased if you don't know what that will cause.\n\nClearing the documents folder will remove all the modules and downloads")
                        .font(.footnote)
                        .foregroundColor(.gray)) {
                
                Button(action: clearCache) {
                    HStack {
                        Text("Clear Cache")
                        Spacer()
                        Image(systemName: "trash")
                            .foregroundColor(.red)
                    }
                    .padding()
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(10)
                }
                
                Button(action: {
                    showEraseAppDataAlert = true
                }) {
                    HStack {
                        Text("Erase all App Data")
                        Spacer()
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.red)
                    }
                    .padding()
                    .background(Color.red.opacity(0.1))
                    .cornerRadius(10)
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
                    HStack {
                        Text("Remove All Files in Documents")
                        Spacer()
                        Image(systemName: "doc.badge.xmark")
                            .foregroundColor(.red)
                    }
                    .padding()
                    .background(Color.red.opacity(0.1))
                    .cornerRadius(10)
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
        .background(
            ZStack {
                Color(.systemBackground)
                    .opacity(0.95)
            }
        )
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(Color.secondary.opacity(0.2), lineWidth: 0.5)
        )
        .shadow(
            color: colorScheme == .dark ? Color(.label).opacity(0.1) : Color.black.opacity(0.15),
            radius: 5, x: 0, y: 2
        )
        .padding(.horizontal, 16)
        .padding(.bottom, 75)
        .padding(.top, 10)
        .frame(minHeight: 600)
        .navigationBarTitleDisplayMode(.inline)
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
        if let documentsURL = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first {
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
