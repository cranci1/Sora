//
//  ModuleAdditionSettingsView.swift
//  Sora
//
//  Created by Francesco on 01/02/25.
//

import Kingfisher
import SwiftUI

struct ModuleAdditionSettingsView: View {
    @Environment(\.presentationMode) var presentationMode
    @EnvironmentObject var moduleManager: ModuleManager

    @State private var moduleMetadata: ModuleMetadata?
    @State private var isLoading = false
    @State private var errorMessage: String?
    var moduleUrl: String

    var body: some View {
        VStack {
            ScrollView {
                VStack {
                    if let metadata = moduleMetadata {
                        VStack(spacing: 25) {
                            VStack(spacing: 15) {
                                KFImage(URL(string: metadata.iconUrl))
                                    .resizable()
                                    .aspectRatio(contentMode: .fit)
                                    .frame(width: 120, height: 120)
                                    .clipShape(Circle())
                                    .shadow(radius: 5)
                                    .transition(.scale)

                                Text(metadata.sourceName)
                                    .font(.system(size: 28, weight: .bold))
                                    .multilineTextAlignment(.center)
                            }
                            .padding(.top)

                            Divider()

                            HStack(spacing: 15) {
                                KFImage(URL(string: metadata.author.icon))
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                                    .frame(width: 60, height: 60)
                                    .clipShape(Circle())
                                    .shadow(radius: 3)

                                VStack(alignment: .leading, spacing: 4) {
                                    Text(metadata.author.name)
                                        .font(.headline)
                                    Text("Author")
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                }
                                Spacer()
                            }
                            .padding(.horizontal)

                            Divider()

                            VStack(alignment: .leading, spacing: 12) {
                                InfoRow(title: "Version", value: metadata.version)
                                InfoRow(title: "Language", value: metadata.language)
                                InfoRow(title: "Quality", value: metadata.quality)
                                InfoRow(title: "Stream Typed", value: metadata.streamType)
                                InfoRow(title: "Base URL", value: metadata.baseUrl)
                                    .onLongPressGesture {
                                        UIPasteboard.general.string = metadata.baseUrl
                                        DropManager.shared.showDrop(title: "Copied to Clipboard", subtitle: "", duration: 1.0, icon: UIImage(systemName: "doc.on.clipboard.fill"))
                                    }
                                InfoRow(title: "Script URL", value: metadata.scriptUrl)
                                    .onLongPressGesture {
                                        UIPasteboard.general.string = metadata.scriptUrl
                                        DropManager.shared.showDrop(title: "Copied to Clipboard", subtitle: "", duration: 1.0, icon: UIImage(systemName: "doc.on.clipboard.fill"))
                                    }
                            }
                            .padding(.horizontal)
                        }

                        Divider()
                    } else if isLoading {
                        VStack(spacing: 20) {
                            ProgressView()
                                .scaleEffect(1.5)
                            Text("Loading module information...")
                                .foregroundColor(.secondary)
                        }
                        .frame(maxHeight: .infinity)
                        .padding(.top, 100)
                    } else if let errorMessage {
                        VStack(spacing: 20) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .font(.system(size: 50))
                                .foregroundColor(.red)
                                .accessibilityLabel("Error Icon")
                            Text(errorMessage)
                                .foregroundColor(.red)
                                .multilineTextAlignment(.center)
                        }
                        .frame(maxHeight: .infinity)
                        .padding(.top, 100)
                    }
                }
            }

            Spacer()

            VStack {
                Button(action: addModule) {
                    HStack {
                        Image(systemName: "plus.circle.fill")
                            .accessibilityLabel("+ Icon")
                        Text("Add Module")
                    }
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 15)
                            .fill(Color.accentColor)
                    )
                    .padding(.horizontal)
                }
                .disabled(isLoading)
                .opacity(isLoading ? 0.6 : 1)

                Button(action: {
                    presentationMode.wrappedValue.dismiss()
                }) {
                    Text("Cancel")
                        .foregroundColor(.accentColor)
                        .padding(.top, 10)
                }
            }
            .padding(.bottom, 20)
        }
        .navigationTitle("Add Module")
        .onAppear(perform: fetchModuleMetadata)
    }

    private func fetchModuleMetadata() {
        isLoading = true
        errorMessage = nil

        Task {
            guard let url = URL(string: moduleUrl) else {
                await MainActor.run {
                    errorMessage = "Invalid URL"
                    isLoading = false
                    Logger.shared.log("Failed to open add module ui with url: \(moduleUrl)", type: .error)
                }
                return
            }
            do {
                let (data, _) = try await URLSession.custom.data(from: url)
                let metadata = try JSONDecoder().decode(ModuleMetadata.self, from: data)
                await MainActor.run {
                    moduleMetadata = metadata
                    isLoading = false
                }
            } catch {
                await MainActor.run {
                    errorMessage = "Failed to fetch module: \(error.localizedDescription)"
                    isLoading = false
                }
            }
        }
    }

    private func addModule() {
        isLoading = true
        Task {
            do {
                _ = try await moduleManager.addModule(metadataUrl: moduleUrl)
                await MainActor.run {
                    isLoading = false
                    DropManager.shared.showDrop(title: "Module Added", subtitle: "Click it to select it.", duration: 2.0, icon: UIImage(systemName: "gear.badge.checkmark"))
                    presentationMode.wrappedValue.dismiss()
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

struct InfoRow: View {
    let title: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.subheadline)
                .foregroundColor(.secondary)
            Text(value)
                .font(.body)
                .lineLimit(1)
        }
    }
}
