//
//  Untitled.swift
//  Sora
//
//  Created by seiike on 16/01/2025.
//

import SwiftUI
import Combine
import Kingfisher

class LogManager: ObservableObject {
    static let shared = LogManager()
    
    @Published var logs: [String] = []
    private var logSubscription: AnyCancellable?

    private init() {
        redirectStandardOutput()
    }

    private func redirectStandardOutput() {
        let pipe = Pipe()
        dup2(pipe.fileHandleForWriting.fileDescriptor, FileHandle.standardOutput.fileDescriptor)

        logSubscription = NotificationCenter.default
            .publisher(for: FileHandle.readCompletionNotification, object: pipe.fileHandleForReading)
            .compactMap { notification in
                (notification.userInfo?[NSFileHandleNotificationDataItem] as? Data)
                    .flatMap { String(data: $0, encoding: .utf8) }
            }
            .receive(on: DispatchQueue.main)
            .sink { [weak self] logMessage in
                self?.logs.append(logMessage.trimmingCharacters(in: .whitespacesAndNewlines))
            }

        pipe.fileHandleForReading.readInBackgroundAndNotify()
    }
}

struct LogViewer: View {
    @ObservedObject private var logManager = LogManager.shared

    var body: some View {
        NavigationView {
            List(logManager.logs, id: \ .self) { log in
                Text(log)
                    .font(.system(size: 14, weight: .regular, design: .monospaced))
            }
            .navigationTitle("Logs")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Clear") {
                        logManager.logs.removeAll()
                    }
                }
            }
        }
    }
}

