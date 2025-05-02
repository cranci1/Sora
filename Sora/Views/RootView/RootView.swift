//
//  ContentView.swift
//  Sora
//
//  Created by Francesco on 06/01/25.
//

import SwiftUI

struct RootView: View {
    @AppStorage("hideExploreTab") private var hideExploreTab: Bool?

    var body: some View {
        TabView {
            if !(hideExploreTab ?? false) {
                ExploreView()
                    .tabItem {
                        Label("Explore", systemImage: "star")
                    }
            }
            SearchView()
                .tabItem {
                    Label("Search", systemImage: "magnifyingglass")
                }
            LibraryView()
                .tabItem {
                    Label("Library", systemImage: "books.vertical")
                }
            SettingsView()
                .tabItem {
                    Label("Settings", systemImage: "gear")
                }
        }
    }
}
