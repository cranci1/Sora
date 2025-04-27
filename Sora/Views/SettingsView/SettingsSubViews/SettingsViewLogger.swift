//
//  SettingsViewLogger.swift
//  Sora
//
//  Created by seiike on 16/01/2025.
//

import SwiftUI

struct SettingsViewLogger: View {
    @State private var logs: String = ""
    @StateObject private var filterViewModel = LogFilterViewModel.shared
    
    var body: some View {
        VStack {
            ScrollView {
                Text(logs)
                    .font(.footnote)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
#if !os(tvOS)
                    .textSelection(.enabled)
#endif
            }
            .navigationTitle("Logs")
            .onAppear {
                logs = Logger.shared.getLogs()
            }
        }
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                HStack {
                    Menu {
#if !os(tvOS)
                        Button(action: {
                            UIPasteboard.general.string = logs
                            DropManager.shared.showDrop(title: "Copied to Clipboard", subtitle: "", duration: 1.0, icon: UIImage(systemName: "doc.on.clipboard.fill"))
                        }) {
                            Label("Copy to Clipboard", systemImage: "doc.on.doc")
                        }
#endif
                        Button(role: .destructive, action: {
                            Logger.shared.clearLogs()
                            logs = Logger.shared.getLogs()
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
}
