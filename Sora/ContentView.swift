//
//  ContentView.swift
//  Sora
//
//  Created by Francesco on 06/01/25.
//

import SwiftUI
import Kingfisher

struct ContentView: View {
    var body: some View {
        TabView {
            LibraryView()
                .tabItem {
                    Label("Library", systemImage: "books.vertical")
                }
            SearchView()
                .tabItem {
                    Label("Search", systemImage: "magnifyingglass")
                }
            DownloadView()
                .environmentObject(JSController.shared)
                .tabItem {
                    Label("Downloads", systemImage: "arrow.down.circle")
                }
            SettingsView()
                .tabItem {
                    Label("Settings", systemImage: "gear")
                }
        }
    }
}
