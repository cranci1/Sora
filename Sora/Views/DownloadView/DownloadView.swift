//
//  DownloadView.swift
//  Sulfur
//
//  Created by Francesco on 12/03/25.
//

import SwiftUI

struct DownloadItem: Identifiable {
    let id = UUID()
    let title: String
    let episode: Int
    let type: String
    var progress: Double
    var status: String
}

class DownloadViewModel: ObservableObject {
    @Published var downloads: [DownloadItem] = []
    
    init() {
        NotificationCenter.default.addObserver(self, selector: #selector(updateStatus(_:)), name: .DownloadManagerStatusUpdate, object: nil)
    }
    
    @objc func updateStatus(_ notification: Notification) {
        guard let info = notification.userInfo,
              let title = info["title"] as? String,
              let episode = info["episode"] as? Int,
              let type = info["type"] as? String,
              let status = info["status"] as? String,
              let progress = info["progress"] as? Double else { return }
        
        if let index = downloads.firstIndex(where: { $0.title == title && $0.episode == episode }) {
            downloads[index] = DownloadItem(title: title, episode: episode, type: type, progress: progress, status: status)
        } else {
            let newDownload = DownloadItem(title: title, episode: episode, type: type, progress: progress, status: status)
            downloads.append(newDownload)
        }
    }
}

struct DownloadView: View {
    @StateObject var viewModel = DownloadViewModel()
    
    var body: some View {
        NavigationView {
            List(viewModel.downloads) { download in
                HStack(spacing: 16) {
                    Image(systemName: iconName(for: download))
                        .resizable()
                        .frame(width: 30, height: 30)
                        .foregroundColor(.accentColor)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("\(download.title) - Episode \(download.episode)")
                            .font(.headline)
                        
                        ProgressView(value: download.progress)
                            .progressViewStyle(LinearProgressViewStyle(tint: .accentColor))
                            .frame(height: 8)
                        
                        Text(download.status)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                }
                .padding(.vertical, 8)
            }
            .navigationTitle("Downloads")
        }
        .navigationViewStyle(StackNavigationViewStyle())
    }
    
    func iconName(for download: DownloadItem) -> String {
        if download.type == "hls" {
            return download.status.lowercased().contains("converting") ? "arrow.triangle.2.circlepath.circle.fill" : "checkmark.circle.fill"
        } else {
            return download.progress >= 1.0 ? "checkmark.circle.fill" : "arrow.down.circle.fill"
        }
    }
}
