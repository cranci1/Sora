//
//  SettingsViewBackup.swift
//  Sora
//
//  Created by paul on 29/06/25.
//

import SwiftUI
import Foundation
import UniformTypeIdentifiers
import UIKit

fileprivate func backupsFolderURL() -> URL {
    let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    let backups = docs.appendingPathComponent("Backups")
    if !FileManager.default.fileExists(atPath: backups.path) {
        try? FileManager.default.createDirectory(at: backups, withIntermediateDirectories: true, attributes: nil)
    }
    return backups
}

fileprivate func listBackupFiles() -> [URL] {
    let folder = backupsFolderURL()
    let files = (try? FileManager.default.contentsOfDirectory(at: folder, includingPropertiesForKeys: nil)) ?? []
    return files.filter { $0.pathExtension == "json" }
        .sorted { $0.lastPathComponent > $1.lastPathComponent }
}

struct ShareSheet: UIViewControllerRepresentable {
    let activityItems: [Any]
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
    }
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

fileprivate struct SettingsSection<Content: View>: View {
    let title: String
    let footer: String?
    let content: Content
    
    init(title: String, footer: String? = nil, @ViewBuilder content: () -> Content) {
        self.title = title
        self.footer = footer
        self.content = content()
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title.uppercased())
                .font(.footnote)
                .foregroundStyle(.gray)
                .padding(.horizontal, 20)
            
            VStack(spacing: 0) {
                content
            }
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(
                        LinearGradient(
                            gradient: Gradient(stops: [
                                .init(color: Color.accentColor.opacity(0.3), location: 0),
                                .init(color: Color.accentColor.opacity(0), location: 1)
                            ]),
                            startPoint: .top,
                            endPoint: .bottom
                        ),
                        lineWidth: 0.5
                    )
            )
            .padding(.horizontal, 20)
            
            if let footer = footer {
                Text(footer)
                    .font(.footnote)
                    .foregroundStyle(.gray)
                    .padding(.horizontal, 20)
                    .padding(.top, 4)
            }
        }
    }
}

fileprivate struct SettingsActionRow: View {
    let icon: String
    let title: String
    let action: () -> Void
    var showDivider: Bool = true
    var color: Color = .accentColor
    
    var body: some View {
        Button(action: action) {
            HStack {
                Image(systemName: icon)
                    .frame(width: 24, height: 24)
                    .foregroundStyle(color)
                Text(title)
                    .foregroundStyle(color)
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
        .buttonStyle(PlainButtonStyle())
        .background(Color.clear)
        .contentShape(Rectangle())
        .overlay(
            VStack {
                if showDivider {
                    Divider().padding(.leading, 56)
                }
            }, alignment: .bottom
        )
    }
}

fileprivate struct BackupCoverageItem: View {
    let icon: String
    let title: String
    let isIncluded: Bool
    var showDivider: Bool = false
    
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .frame(width: 24, height: 24)
                .foregroundStyle(isIncluded ? Color.green : Color.red)
            
            Text(title)
                .foregroundStyle(Color.primary)
            
            Spacer()
            
            Image(systemName: isIncluded ? "checkmark.circle.fill" : "xmark.circle.fill")
                .foregroundStyle(isIncluded ? Color.green : Color.red)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 6)
        .contentShape(Rectangle())
    }
}

fileprivate struct BackupCoverageView: View {
    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                Image(systemName: "checkmark.circle")
                    .foregroundColor(.gray)
                Text(NSLocalizedString("Included", comment: "Title for items included in backup"))
                    .font(.footnote)
                    .foregroundColor(.secondary)
                Rectangle()
                    .fill(Color.secondary.opacity(0.3))
                    .frame(height: 1)
                    .frame(maxWidth: .infinity)
            }
            .padding(.vertical, 4)
            BackupCoverageItem(icon: "film", title: NSLocalizedString("Continue Watching", comment: "Continue watching backup item"), isIncluded: true, showDivider: false)
            BackupCoverageItem(icon: "book", title: NSLocalizedString("Continue Reading", comment: "Continue reading backup item"), isIncluded: true, showDivider: false)
            BackupCoverageItem(icon: "bookmark", title: NSLocalizedString("Collections & Bookmarks", comment: "Collections backup item"), isIncluded: true, showDivider: false)
            BackupCoverageItem(icon: "magnifyingglass", title: NSLocalizedString("Search History", comment: "Search history backup item"), isIncluded: true, showDivider: false)
            BackupCoverageItem(icon: "puzzlepiece", title: NSLocalizedString("Modules", comment: "Modules backup item"), isIncluded: true, showDivider: false)
            BackupCoverageItem(icon: "gearshape", title: NSLocalizedString("User Settings", comment: "User settings backup item"), isIncluded: true, showDivider: false)
            HStack(spacing: 8) {
                Image(systemName: "xmark.circle")
                    .foregroundColor(.gray)
                Text(NSLocalizedString("Not Included", comment: "Title for items not included in backup"))
                    .font(.footnote)
                    .foregroundColor(.secondary)
                Rectangle()
                    .fill(Color.secondary.opacity(0.3))
                    .frame(height: 1)
                    .frame(maxWidth: .infinity)
            }
            .padding(.vertical, 4)
            BackupCoverageItem(icon: "arrow.down.circle", title: NSLocalizedString("Downloaded Files", comment: "Downloads backup item"), isIncluded: false, showDivider: false)
            BackupCoverageItem(icon: "person.crop.circle", title: NSLocalizedString("Account Logins", comment: "Account logins backup item"), isIncluded: false, showDivider: false)
        }
    }
}

struct SettingsViewBackup: View {
    @State private var showAlert = false
    @State private var alertMessage = ""
    @State private var selectedBackup: URL? = nil
    @State private var showImportNotice = false
    @State private var showBackupList = false
    
    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 24) {
                VStack(spacing: 0) {
                    VStack(spacing: 0) {
                        SettingsNavigationRow(icon: "arrow.up.doc", title: NSLocalizedString("Save Backup", comment: "Save backup button title"), showChevron: false, textColor: .accentColor) {
                            if let data = generateBackupData() {
                                let url = backupsFolderURL().appendingPathComponent(exportFilename())
                                do {
                                    try data.write(to: url)
                                    alertMessage = "Backup saved to Backups folder."
                                } catch {
                                    alertMessage = "Failed to save backup: \(error.localizedDescription)"
                                }
                                showAlert = true
                            }
                        }
                        Divider()
                    }
                    .padding(.horizontal, 16)
                    VStack(spacing: 0) {
                        SettingsNavigationRow(icon: "arrow.down.doc", title: NSLocalizedString("Import Backup", comment: "Import backup button title"), showChevron: false, textColor: .accentColor) {
                            showImportNotice = true
                        }
                        Divider()
                    }
                    .padding(.horizontal, 16)
                    VStack(spacing: 0) {
                        SettingsNavigationRow(icon: "folder", title: "Show Backups", showChevron: true, textColor: .accentColor) {
                            showBackupList = true
                        }
                    }
                    .padding(.horizontal, 16)
                }
                .background(.ultraThinMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .strokeBorder(
                            LinearGradient(
                                gradient: Gradient(stops: [
                                    .init(color: Color.accentColor.opacity(0.3), location: 0),
                                    .init(color: Color.accentColor.opacity(0), location: 1)
                                ]),
                                startPoint: .top,
                                endPoint: .bottom
                            ),
                            lineWidth: 0.5
                        )
                )
                .padding(.horizontal, 20)
                NavigationLink(destination: BackupListView(), isActive: $showBackupList) { EmptyView() }
                VStack(alignment: .leading, spacing: 8) {
                    BackupCoverageView()
                        .padding(.horizontal, 20)
                }
                Text(NSLocalizedString("Notice: This feature is still experimental. Please double-check your data after import/export. \nAlso note that when importing a backup your current data will be overwritten, it is not possible to merge yet.", comment: "Footer notice for experimental backup/restore feature"))
                    .font(.footnote)
                    .foregroundColor(.gray)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 20)
                    .padding(.top, 8)
            }
            .scrollViewBottomPadding()
            .padding(.bottom, 20)
            .padding(.top, 20)
        }
        .navigationTitle(NSLocalizedString("Backup & Restore", comment: "Navigation title for backup and restore view"))
        .alert(isPresented: $showAlert) {
            Alert(title: Text(NSLocalizedString("Backup", comment: "Alert title for backup actions")), message: Text(alertMessage), dismissButton: .default(Text("OK")))
        }
        .sheet(isPresented: $showImportNotice) {
            ImportNoticeView()
        }
    }
    
    private func exportFilename() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd_HH-mm-ss"
        let dateString = formatter.string(from: Date())
        return "SoraBackup_\(dateString).json"
    }
}

@MainActor private func generateBackupData() -> Data? {
        let continueWatching = ContinueWatchingManager.shared.fetchItems()
        let continueReading = ContinueReadingManager.shared.fetchItems()
        let collections = (try? JSONDecoder().decode([BookmarkCollection].self, from: UserDefaults.standard.data(forKey: "bookmarkCollections") ?? Data())) ?? []
        let searchHistory = UserDefaults.standard.stringArray(forKey: "searchHistory") ?? []
        let modules = ModuleManager().modules 

        let userSettingsKeys: [String] = [
            "episodeChunkSize",
            "fetchEpisodeMetadata",
            "analyticsEnabled",
            "hideSplashScreen",
            "useNativeTabBar",
            "metadataProvidersOrderData",
            "tmdbImageWidth",
            "metadataProviders",
            "externalPlayer",
            "alwaysLandscape",
            "rememberPlaySpeed",
            "holdSpeedPlayer",
            "skipIncrement",
            "skipIncrementHold",
            "remainingTimePercentage",
            "holdForPauseEnabled",
            "skip85Visible",
            "doubleTapSeekEnabled",
            "skipIntroOutroVisible",
            "pipButtonVisible",
            "autoplayNext",
            "videoQualityWiFi",
            "videoQualityCellular",
            "subtitlesEnabled",
            "allowCellularDownloads",
            "maxConcurrentDownloads",
            "downloadQuality",
            "mediaColumnsPortrait",
            "mediaColumnsLandscape",
            "librarySectionsOrderData",
            "disabledLibrarySectionsData",
            "selectedModuleId",
            "didReceiveDefaultPageLink",
            "refreshModulesOnLaunch",
            "sendPushUpdates",
            "sendTraktUpdates",
            "selectedAppearance",
            "selectedLanguage",
            "metadataProvidersOrder",
            "chapterChunkSize",
            "lastCommunityURL"
        ]
        var userSettings: [String: Any] = [:]
        for key in userSettingsKeys {
            if let data = UserDefaults.standard.object(forKey: key) as? Data {
                userSettings[key] = data.base64EncodedString()
            } else {
                userSettings[key] = UserDefaults.standard.object(forKey: key)
            }
        }
        if let subtitleSettings = UserDefaults.standard.data(forKey: "SubtitleSettings") {
            userSettings["SubtitleSettings"] = subtitleSettings.base64EncodedString()
        }
        if let logFilterStates = UserDefaults.standard.dictionary(forKey: "LogFilterStates") {
            userSettings["LogFilterStates"] = logFilterStates
        }
        if let segmentsColorData = UserDefaults.standard.data(forKey: "segmentsColorData") {
            userSettings["segmentsColorData"] = segmentsColorData.base64EncodedString()
        }
        let backup: [String: Any] = [
            "continueWatching": continueWatching.map { try? $0.toDictionary() },
            "continueReading": continueReading.map { try? $0.toDictionary() },
            "collections": collections.map { try? $0.toDictionary() },
            "searchHistory": searchHistory,
            "modules": modules.map { try? $0.toDictionary() },
            "userSettings": userSettings
        ]
        return try? JSONSerialization.data(withJSONObject: backup, options: .prettyPrinted)
    }
    
    private func restoreBackupData(_ data: Data) throws {
        guard let json = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any] else {
            throw NSError(domain: "restoreBackupData", code: 0, userInfo: [NSLocalizedDescriptionKey: "Invalid backup format"])
        }
        if let cwArr = json["continueWatching"] as? NSArray {
            let cwData = try JSONSerialization.data(withJSONObject: cwArr, options: [])
            UserDefaults.standard.set(cwData, forKey: "continueWatchingItems")
        }
        if let crArr = json["continueReading"] as? NSArray {
            let crData = try JSONSerialization.data(withJSONObject: crArr, options: [])
            UserDefaults.standard.set(crData, forKey: "continueReadingItems")
        }
        if let colArr = json["collections"] as? NSArray {
            let colData = try JSONSerialization.data(withJSONObject: colArr, options: [])
            UserDefaults.standard.set(colData, forKey: "bookmarkCollections")
        }
        if let shArr = json["searchHistory"] as? [String] {
            UserDefaults.standard.set(shArr, forKey: "searchHistory")
        }
        if let modArr = json["modules"] as? NSArray {
            let modData = try JSONSerialization.data(withJSONObject: modArr, options: [])
            let fileManager = FileManager.default
            let docs = fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
            let modulesURL = docs.appendingPathComponent("modules.json")
            try modData.write(to: modulesURL)
        }
        // Restore user settings if present
        if let userSettings = json["userSettings"] as? [String: Any] {
            for (key, value) in userSettings {
                if let str = value as? String, let data = Data(base64Encoded: str), ["SubtitleSettings", "segmentsColorData", "metadataProvidersOrderData", "librarySectionsOrderData", "disabledLibrarySectionsData"].contains(key) {
                    UserDefaults.standard.set(data, forKey: key)
                } else {
                    UserDefaults.standard.set(value, forKey: key)
                }
            }
        }
        UserDefaults.standard.synchronize()
    }
    
fileprivate struct SettingsNavigationRow: View {
    let icon: String
    let title: String
    let showChevron: Bool
    let textColor: Color
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            HStack {
                Image(systemName: icon)
                    .frame(width: 24, height: 24)
                    .foregroundStyle(textColor)
                Text(title)
                    .foregroundStyle(textColor)
                Spacer()
                if showChevron {
                    Image(systemName: "chevron.right")
                        .foregroundStyle(.gray)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
        .buttonStyle(PlainButtonStyle())
        .background(Color.clear)
        .contentShape(Rectangle())
    }
}

struct BackupListView: View {
    @State private var backups: [URL] = []
    @State private var showShareSheet = false
    @State private var shareURL: URL? = nil
    @State private var selectedBackup: URL? = nil
    @State private var deleteURL: URL? = nil
    @State private var alertMessage = ""
    @State private var activeAlert: ActiveAlert? = nil

    private enum ActiveAlert: Identifiable {
        case delete, importBackup, info
        var id: Int {
            switch self {
            case .delete: return 0
            case .importBackup: return 1
            case .info: return 2
            }
        }
    }

    private func refreshBackups() {
        backups = listBackupFiles()
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 24) {
                VStack(spacing: 0) {
                    ForEach(backups.indices, id: \ .self) { idx in
                        let url = backups[idx]
                        VStack(spacing: 0) {
                            SettingsNavigationRow(
                                icon: "doc",
                                title: url.lastPathComponent,
                                showChevron: false,
                                textColor: .accentColor
                            ) {
                                selectedBackup = url
                                activeAlert = .importBackup
                            }
                            .contextMenu {
                                Button("Export", systemImage: "square.and.arrow.up") {
                                    shareURL = url
                                    showShareSheet = true
                                }
                                Button("Delete", role: .destructive, action: {
                                    deleteURL = url
                                    activeAlert = .delete
                                })
                            }
                            if idx != backups.count - 1 {
                                Divider()
                            }
                        }
                        .padding(.horizontal, 16)
                    }
                    if !backups.isEmpty {
                        Divider()
                            .padding(.horizontal, 16)
                    }
                    if backups.isEmpty {
                        Text("No backups found in the Backups folder.")
                            .foregroundColor(.gray)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 20)
                    }
                    if !backups.isEmpty {
                        Text("Tap on a backup to import it.")
                            .font(.footnote)
                            .foregroundColor(.secondary)
                            .frame(maxWidth: .infinity, alignment: .center)
                            .padding(.top, 16)
                            .padding(.bottom, 8)
                    }
                }
                .background(.ultraThinMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .strokeBorder(
                            LinearGradient(
                                gradient: Gradient(stops: [
                                    .init(color: Color.accentColor.opacity(0.3), location: 0),
                                    .init(color: Color.accentColor.opacity(0), location: 1)
                                ]),
                                startPoint: .top,
                                endPoint: .bottom
                            ),
                            lineWidth: 0.5
                        )
                )
                .padding(.horizontal, 20)
            }
            .padding(.top, 20)
        }
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: { refreshBackups() }) {
                    Image(systemName: "arrow.clockwise")
                }
            }
        }
        .onAppear(perform: refreshBackups)
        .sheet(isPresented: $showShareSheet) {
            if let url = shareURL {
                ShareSheet(activityItems: [url])
            }
        }
        .alert(item: $activeAlert) { alertType in
            switch alertType {
            case .delete:
                return Alert(
                    title: Text("Delete Backup"),
                    message: Text("Are you sure you want to delete this backup?"),
                    primaryButton: .destructive(Text("Delete")) {
                        if let url = deleteURL {
                            try? FileManager.default.removeItem(at: url)
                            refreshBackups()
                        }
                    },
                    secondaryButton: .cancel()
                )
            case .importBackup:
                return Alert(
                    title: Text("Import Backup"),
                    message: Text("Are you sure you want to import this backup? This will overwrite your current data."),
                    primaryButton: .destructive(Text("Import")) {
                        if let url = selectedBackup {
                            do {
                                let data = try Data(contentsOf: url)
                                try restoreBackupData(data)
                                alertMessage = "Import successful! The app will now restart to apply the changes."
                            } catch {
                                alertMessage = "Import failed: \(error.localizedDescription)"
                            }
                            activeAlert = .info
                        }
                    },
                    secondaryButton: .cancel()
                )
            case .info:
                return Alert(title: Text("Backup"), message: Text(alertMessage), dismissButton: .default(Text("OK")) {
                    if alertMessage.contains("restart") {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                            exit(0)
                        }
                    }
                })
            }
        }
        .navigationTitle("Backups")
    }
}

struct ImportNoticeView: View {
    var body: some View {
        VStack(spacing: 0) {
            Spacer()
            VStack(spacing: 20) {
                Image(systemName: "arrow.down.doc")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 48, height: 48)
                    .foregroundColor(.accentColor)
                Text("How to Import a Backup")
                    .font(.title2).bold()
                    .padding(.bottom, 8)
                VStack(alignment: .leading, spacing: 16) {
                    HStack(alignment: .top, spacing: 10) {
                        Image(systemName: "1.circle.fill").foregroundColor(.accentColor)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Open the **Files** app on your device.")
                            Text("")
                        }
                    }
                    HStack(alignment: .top, spacing: 10) {
                        Image(systemName: "2.circle.fill").foregroundColor(.accentColor)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Navigate to:")
                            Text("**On My iPhone/iPad** > **Sora** > **Backups**")
                                .font(.callout)
                                .foregroundColor(.secondary)
                        }
                    }
                    HStack(alignment: .top, spacing: 10) {
                        Image(systemName: "3.circle.fill").foregroundColor(.accentColor)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Copy your backup file (ending in **.json**) into the **Backups** folder.")
                        }
                    }
                    HStack(alignment: .top, spacing: 10) {
                        Image(systemName: "4.circle.fill").foregroundColor(.accentColor)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Return to Sora and tap **Show Backups** to see your file.")
                        }
                    }
                }
                .font(.body)
                .padding(.horizontal, 8)
                .padding(.vertical, 8)
                .background(Color(.systemGray6))
                .cornerRadius(12)
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 16)
            Spacer()
        }
    }
}


extension Encodable {
    func toDictionary() throws -> [String: Any] {
        let data = try JSONEncoder().encode(self)
        let json = try JSONSerialization.jsonObject(with: data, options: [])
        guard let dict = json as? [String: Any] else {
            throw NSError(domain: "toDictionary", code: 0, userInfo: nil)
        }
        return dict
    }
}

struct BackupDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.json] }
    var data: Data
    
    init(data: Data) {
        self.data = data
    }
    init(configuration: ReadConfiguration) throws {
        self.data = configuration.file.regularFileContents ?? Data()
    }
    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        return .init(regularFileWithContents: data)
    }
} 
