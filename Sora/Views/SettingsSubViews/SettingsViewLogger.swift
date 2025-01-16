//
//  SettingsViewLogger.swift
//  Sora
//
//  Created by seiike on 16/01/2025.
//

import SwiftUI

struct LogViewer: View {
    @ObservedObject private var logManager = LogManager.shared

    var body: some View {
        NavigationView {
            List(logManager.logs, id: \.self) { log in
                Text(log)
                    .font(.system(size: 14, weight: .regular, design: .monospaced))
            }
            .navigationTitle("Logs")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Clear") {
                        logManager.clearLogs()
                    }
                }
            }
        }
    }
}
