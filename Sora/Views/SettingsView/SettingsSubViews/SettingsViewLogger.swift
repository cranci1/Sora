//
//  SettingsViewLogger.swift
//  Sora
//
//  Created by seiike on 16/01/2025.
//

import SwiftUI
import Kingfisher

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
    @StateObject private var filterViewModel = LogFilterViewModel.shared
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                SettingsSection(title: "Logs") {
                    if isLoading {
                        HStack {
                            ProgressView()
                                .scaleEffect(0.8)
                            Text("Loading logs...")
                                .font(.footnote)
                                .foregroundColor(.secondary)
                        }
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.vertical, 20)
                    } else {
                        Text(logs)
                            .font(.footnote)
                            .foregroundColor(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 12)
                            .textSelection(.enabled)
                    }
                }
            }
            .padding(.vertical, 20)
        }
        .navigationTitle("Logs")
        .onAppear {
            loadLogsAsync()
        }
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                HStack {
                    Menu {
                        Button(action: {
                            UIPasteboard.general.string = logs
                            DropManager.shared.showDrop(title: "Copied to Clipboard", subtitle: "", duration: 1.0, icon: UIImage(systemName: "doc.on.clipboard.fill"))
                        }) {
                            Label("Copy to Clipboard", systemImage: "doc.on.doc")
                        }
                        Button(role: .destructive, action: {
                            clearLogsAsync()
                        }) {
                            Label("Clear Logs", systemImage: "trash")
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
            }
        }
    }
}
