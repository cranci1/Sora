//
//  SettingsViewLogger.swift
//  Sora
//
//  Created by seiike on 16/01/2025.
//

import SwiftUI

struct LogViewer: View {
    @State private var logs: String = ""

    var body: some View {
        
            VStack {
                ScrollView {
                    Text(logs)
                        .font(.footnote)
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding()
                        .textSelection(.enabled)
                }
                .navigationTitle("Logs")
                .onAppear {
                    logs = Logger.shared.getLogs()
                }
            
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Button(action: {
                            UIPasteboard.general.string = logs
                        }) {
                            Label("Copy to Clipboard", systemImage: "doc.on.doc")
                        }
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
                }
            }
        }
    }
}
