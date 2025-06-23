//
//  ContentView.swift
//  Sora
//
//  Created by Francesco on 06/01/25.
//
import SwiftUI

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
            .environmentObject(LibraryManager())
            .environmentObject(ModuleManager())
            .environmentObject(Settings())
    }
}

struct ContentView: View {
    @AppStorage("useNativeTabBar") private var useNativeTabBar: Bool = false
    @StateObject private var tabBarController = TabBarController()
    @State var selectedTab: Int = 0
    @State var lastTab: Int = 0
    @State private var searchQuery: String = ""
    
    let tabs: [TabItem] = [
        TabItem(icon: "square.stack", title: NSLocalizedString("LibraryTab", comment: "")),
        TabItem(icon: "arrow.down.circle", title: NSLocalizedString("DownloadsTab", comment: "")),
        TabItem(icon: "gearshape", title: NSLocalizedString("SettingsTab", comment: "")),
        TabItem(icon: "magnifyingglass", title: NSLocalizedString("SearchTab", comment: ""))
    ]

    private func tabView(for index: Int) -> some View {
        switch index {
            case 1: return AnyView(DownloadView())
            case 2: return AnyView(SettingsView())
            case 3: return AnyView(SearchView(searchQuery: $searchQuery))
            default: return AnyView(LibraryView())
        }
    }

    var body: some View {
        if #available(iOS 26, *), useNativeTabBar == true {
            TabView {
                ForEach(Array(tabs.enumerated()), id: \.offset) { index, item in
                    Tab(item.title, systemImage: item.icon, role: index == 3 ? .search : nil) {
                        tabView(for: index)
                    }
                }
            }
            .searchable(text: $searchQuery)
            .environmentObject(tabBarController)
        } else {
            ZStack(alignment: .bottom) {
                Group {
                    tabView(for: selectedTab)
                }
                .environmentObject(tabBarController)

                TabBar(
                    tabs: tabs,
                    selectedTab: $selectedTab,
                    lastTab: $lastTab,
                    searchQuery: $searchQuery,
                    controller: tabBarController
                )
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
            .ignoresSafeArea(.keyboard, edges: .bottom)
            .padding(.bottom, -20)
        }
    }
}
