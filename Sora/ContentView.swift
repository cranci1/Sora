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
            ExploreView()
                .tabItem {
                    Label("Explore", systemImage: "star")
                }
            LibraryView()
                .tabItem {
                    Label("Library", systemImage: "books.vertical")
                }
            SearchView()
                .tabItem {
                    Label("Search", systemImage: "magnifyingglass")
                }
            SettingsView()
                .tabItem {
                    Label("Settings", systemImage: "gear")
                }
        }
    }
}
