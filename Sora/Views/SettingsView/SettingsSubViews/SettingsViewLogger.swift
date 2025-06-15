//
//  SettingsViewLogger.swift
//  Sora
//
//  Created by seiike on 16/01/2025.
//

import SwiftUI

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
        .scrollViewBottomPadding()
    }
}

struct SettingsViewLogger: View {
    @State private var logs: String = ""
    @State private var isLoading: Bool = true
    @State private var showFullLogs: Bool = false
    @StateObject private var filterViewModel = LogFilterViewModel.shared
    
    private let displayCharacterLimit = 50_000
    
    var displayedLogs: String {
        if showFullLogs || logs.count <= displayCharacterLimit {
            return logs
        }
        return String(logs.suffix(displayCharacterLimit))
    }
    
    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 24) {
                SettingsSection(title: NSLocalizedString("Logs", comment: "")) {
                    if isLoading {
                        HStack {
                            ProgressView()
                                .scaleEffect(0.8)
                            Text(NSLocalizedString("Loading logs...", comment: ""))
                                .font(.footnote)
                                .foregroundColor(.secondary)
                        }
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.vertical, 20)
                    } else {
                        VStack(alignment: .leading, spacing: 8) {
                            Text(displayedLogs)
                                .font(.footnote)
                                .foregroundColor(.secondary)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .textSelection(.enabled)
                            
                            if logs.count > displayCharacterLimit && !showFullLogs {
                                Button(action: {
                                    showFullLogs = true
                                }) {
                                    Text(NSLocalizedString("Show More (%lld more characters)", comment: "").replacingOccurrences(of: "%lld", with: "\(logs.count - displayCharacterLimit)"))
                                        .font(.footnote)
                                        .foregroundColor(.accentColor)
                                }
                                .padding(.top, 8)
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                    }
                }
            }
            .padding(.vertical, 20)
        }
        .navigationTitle(NSLocalizedString("Logs", comment: ""))
        .onAppear {
            loadLogsAsync()
        }
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                HStack {
                    Menu {
                        Button(action: {
                            UIPasteboard.general.string = logs
                            DropManager.shared.showDrop(title: NSLocalizedString("Copied to Clipboard", comment: ""), subtitle: "", duration: 1.0, icon: UIImage(systemName: "doc.on.clipboard.fill"))
                        }) {
                            Label(NSLocalizedString("Copy to Clipboard", comment: ""), systemImage: "doc.on.doc")
                        }
                        Button(role: .destructive, action: {
                            clearLogsAsync()
                        }) {
                            Label(NSLocalizedString("Clear Logs", comment: ""), systemImage: "trash")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                            .resizable()
                            .frame(width: 20, height: 20)
                    }
                    
                    NavigationLink(destination: SettingsViewLoggerFilter(viewModel: filterViewModel)) {
                        Image(systemName: "slider.horizontal.3")
                    }
                }
            }
        }
    }
    
    private func loadLogsAsync() {
        Task {
            let loadedLogs = await Logger.shared.getLogsAsync()
            await MainActor.run {
                self.logs = loadedLogs
                self.isLoading = false
            }
        }
    }
    
    private func clearLogsAsync() {
        Task {
            await Logger.shared.clearLogsAsync()
            await MainActor.run {
                self.logs = ""
                self.showFullLogs = false
            }
        }
    }
}
