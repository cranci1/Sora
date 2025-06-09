//
//  ModuleAdditionSettingsView.swift
//  Sora
//
//  Created by Francesco on 01/02/25.
//

import NukeUI
import SwiftUI

struct ModuleAdditionSettingsView: View {
    @Environment(\.presentationMode) var presentationMode
    @EnvironmentObject var moduleManager: ModuleManager
    @Environment(\.colorScheme) var colorScheme
    
    @State private var moduleMetadata: ModuleMetadata?
    @State private var isLoading = false
    @State private var errorMessage: String?
    var moduleUrl: String
    
    var body: some View {
        ZStack {
            LinearGradient(
                gradient: Gradient(colors: [
                    colorScheme == .light ? Color.black : Color.white,
                    Color.accentColor.opacity(0.08)
                ]),
                startPoint: .top,
                endPoint: .bottom
            )
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                HStack {
                    Spacer()
                    Capsule()
                        .frame(width: 40, height: 5)
                        .foregroundColor(Color(.systemGray4))
                        .padding(.top, 10)
                    Spacer()
                }
                .padding(.bottom, 8)
                
                ScrollView {
                    VStack(spacing: 24) {
                        if let metadata = moduleMetadata {
                            VStack(spacing: 0) {
                                LazyImage(url: URL(string: metadata.iconUrl)) { state in
                                    if let uiImage = state.imageContainer?.image {
                                        Image(uiImage: uiImage)
                                            .resizable()
                                            .aspectRatio(contentMode: .fill)
                                    } else {
                                        Rectangle()
                                            .fill(Color(.systemGray5))
                                    }
                                }
                                .frame(width: 90, height: 90)
                                .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                                .shadow(color: Color.accentColor.opacity(0.18), radius: 10, x: 0, y: 6)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 22)
                                        .stroke(Color.accentColor, lineWidth: 2)
                                )
                                .padding(.top, 10)
                                
                                VStack(spacing: 6) {
                                    Text(metadata.sourceName)
                                        .font(.system(size: 28, weight: .bold, design: .rounded))
                                        .foregroundColor(.primary)
                                        .multilineTextAlignment(.center)
                                        .padding(.top, 6)
                                    
                                    HStack(spacing: 10) {
                                        LazyImage(url: URL(string: metadata.author.icon)) { state in
                                            if let uiImage = state.imageContainer?.image {
                                                Image(uiImage: uiImage)
                                                    .resizable()
                                                    .aspectRatio(contentMode: .fill)
                                            } else {
                                                Circle()
                                                    .fill(Color(.systemGray5))
                                            }
                                        }
                                        .frame(width: 32, height: 32)
                                        .clipShape(Circle())
                                        .shadow(radius: 2)
                                        VStack(alignment: .leading, spacing: 0) {
                                            Text(metadata.author.name)
                                                .font(.headline)
                                                .foregroundColor(.primary)
                                            Text("Author")
                                                .font(.caption2)
                                                .foregroundColor(.secondary)
                                        }
                                        Spacer()
                                    }
                                    .padding(.horizontal, 18)
                                    .padding(.vertical, 8)
                                    .background(
                                        Capsule()
                                            .fill(Color.accentColor.opacity(colorScheme == .dark ? 0.13 : 0.08))
                                    )
                                    .padding(.top, 2)
                                }
                                
                                VStack(spacing: 0) {
                                    HStack(spacing: 0) {
                                        FancyInfoTile(icon: "globe", label: "Language", value: metadata.language)
                                        Divider().frame(height: 44)
                                        FancyInfoTile(icon: "film", label: "Type", value: metadata.type ?? "-")
                                    }
                                    Divider()
                                    HStack(spacing: 0) {
                                        FancyInfoTile(icon: "arrow.down.circle", label: "Quality", value: metadata.quality)
                                        Divider().frame(height: 44)
                                        FancyInfoTile(icon: "waveform", label: "Stream", value: metadata.streamType)
                                    }
                                    Divider()
                                    HStack(spacing: 0) {
                                        FancyInfoTile(icon: "number", label: "Version", value: metadata.version)
                                        Divider().frame(height: 44)
                                        FancyInfoTile(icon: "bolt.horizontal", label: "Async JS", value: metadata.asyncJS == true ? "Yes" : "No")
                                    }
                                }
                                .background(
                                    RoundedRectangle(cornerRadius: 22)
                                        .fill(Color(.systemGray6).opacity(colorScheme == .dark ? 0.18 : 0.8))
                                )
                                .padding(.top, 18)
                                .padding(.horizontal, 2)
                                
                                VStack(spacing: 0) {
                                    FancyUrlRow(title: "Base URL", value: metadata.baseUrl)
                                    Divider().padding(.horizontal, 8)
                                    if !metadata.searchBaseUrl.isEmpty {
                                        FancyUrlRow(title: "Search URL", value: metadata.searchBaseUrl)
                                        Divider().padding(.horizontal, 8)
                                    }
                                    FancyUrlRow(title: "Script URL", value: metadata.scriptUrl)
                                }
                                .padding(16)
                                .background(
                                    RoundedRectangle(cornerRadius: 18)
                                        .fill(Color(.systemGray6).opacity(colorScheme == .dark ? 0.13 : 0.85))
                                )
                                .padding(.top, 18)
                            }
                            .padding(.horizontal, 18)
                            .padding(.top, 8)
                        } else if isLoading {
                            VStack(spacing: 20) {
                                ProgressView()
                                    .scaleEffect(1.5)
                                Text("Loading module information...")
                                    .foregroundColor(.secondary)
                            }
                            .frame(maxHeight: .infinity)
                            .padding(.top, 100)
                        } else if let errorMessage = errorMessage {
                            VStack(spacing: 20) {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .font(.system(size: 50))
                                    .foregroundColor(.red)
                                Text(errorMessage)
                                    .foregroundColor(.red)
                                    .multilineTextAlignment(.center)
                            }
                            .frame(maxHeight: .infinity)
                            .padding(.top, 100)
                        }
                    }
                    .padding(.bottom, 30)
                }
                
                VStack(spacing: 10) {
                    Button(action: addModule) {
                        HStack {
                            Image(systemName: "plus.circle.fill")
                            Text("Add Module")
                        }
                        .font(.headline)
                        .foregroundColor(colorScheme == .light ? .black : .white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(
                            LinearGradient(
                                gradient: Gradient(colors: [
                                    Color.accentColor.opacity(0.95),
                                    Color.accentColor.opacity(0.7)
                                ]),
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                            .clipShape(RoundedRectangle(cornerRadius: 18))
                        )
                        .shadow(color: Color.accentColor.opacity(0.18), radius: 8, x: 0, y: 4)
                        .padding(.horizontal, 20)
                    }
                    .disabled(isLoading || moduleMetadata == nil)
                    .opacity(isLoading ? 0.6 : 1)
                    
                    Button(action: { presentationMode.wrappedValue.dismiss() }) {
                        Text("Cancel")
                            .font(.body)
                            .foregroundColor(.secondary)
                            .padding(.vertical, 8)
                    }
                }
                .padding(.bottom, 24)
            }
        }
        .onAppear(perform: fetchModuleMetadata)
    }
    
    private func fetchModuleMetadata() {
        isLoading = true
        errorMessage = nil
        
        Task {
            guard let url = URL(string: moduleUrl) else {
                await MainActor.run {
                    self.errorMessage = "Invalid URL"
                    self.isLoading = false
                    Logger.shared.log("Failed to open add module ui with url: \(moduleUrl)", type: "Error")
                }
                return
            }
            do {
                let (data, _) = try await URLSession.custom.data(from: url)
                let metadata = try JSONDecoder().decode(ModuleMetadata.self, from: data)
                await MainActor.run {
                    self.moduleMetadata = metadata
                    self.isLoading = false
                }
            } catch {
                await MainActor.run {
                    self.errorMessage = "Failed to fetch module: \(error.localizedDescription)"
                    self.isLoading = false
                }
            }
        }
    }
    
    private func addModule() {
        isLoading = true
        Task {
            do {
                let _ = try await moduleManager.addModule(metadataUrl: moduleUrl)
                await MainActor.run {
                    isLoading = false
                    DropManager.shared.showDrop(title: "Module Added", subtitle: "Click it to select it.", duration: 2.0, icon: UIImage(systemName:"gear.badge.checkmark"))
                    self.presentationMode.wrappedValue.dismiss()
                }
            } catch {
                await MainActor.run {
                    isLoading = false
                    if (error as NSError).domain == "Module already exists" {
                        errorMessage = "Module already exists"
                    } else {
                        errorMessage = "Failed to add module: \(error.localizedDescription)"
                    }
                    Logger.shared.log("Failed to add module: \(error.localizedDescription)")
                }
            }
        }
    }
}

struct FancyInfoTile: View {
    let icon: String
    let label: String
    let value: String
    
    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(.accentColor)
            Text(label)
                .font(.caption2)
                .foregroundColor(.secondary)
            Text(value)
                .font(.system(size: 15, weight: .semibold, design: .rounded))
                .foregroundColor(.primary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity, minHeight: 54)
        .padding(.vertical, 6)
    }
}

struct FancyUrlRow: View {
    let title: String
    let value: String
    
    var body: some View {
        HStack(spacing: 8) {
            Text(title)
                .font(.subheadline)
                .foregroundColor(.secondary)
            Spacer()
            Text(value)
                .font(.footnote.monospaced())
                .foregroundColor(.accentColor)
                .lineLimit(1)
                .truncationMode(.middle)
                .onLongPressGesture {
                    UIPasteboard.general.string = value
                    DropManager.shared.showDrop(title: "Copied to Clipboard", subtitle: "", duration: 1.0, icon: UIImage(systemName: "doc.on.clipboard.fill"))
                }
            Image(systemName: "doc.on.clipboard")
                .foregroundColor(.accentColor)
                .font(.system(size: 14))
                .onTapGesture {
                    UIPasteboard.general.string = value
                    DropManager.shared.showDrop(title: "Copied to Clipboard", subtitle: "", duration: 1.0, icon: UIImage(systemName: "doc.on.clipboard.fill"))
                }
        }
        .padding(.vertical, 7)
        .padding(.horizontal, 2)
    }
}
