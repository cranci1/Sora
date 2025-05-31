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
    @StateObject private var tabBarController = TabBarController()
    @State var selectedTab: Int = 0
    @State var lastTab: Int = 0
    @State private var searchQuery: String = ""
    
    let tabs: [TabItem] = [
        TabItem(icon: "square.stack", title: ""),
        TabItem(icon: "arrow.down.circle", title: ""),
        TabItem(icon: "gearshape", title: ""),
        TabItem(icon: "magnifyingglass", title: "")
    ]
    
    var body: some View {
        ZStack(alignment: .bottom) {
            switch selectedTab {
            case 0:
                LibraryView()
                    .environmentObject(tabBarController)
            case 1:
                DownloadView()
                    .environmentObject(tabBarController)
            case 2:
                SettingsView()
                    .environmentObject(tabBarController)
            case 3:
                SearchView(searchQuery: $searchQuery)
                    .environmentObject(tabBarController)
            default:
                LibraryView()
                    .environmentObject(tabBarController)
            }
            
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
