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
    @State var selectedTab: Int = 0
    @State var lastTab: Int = 0
    @State private var searchQuery: String = ""
    
    let tabs: [TabItem] = [
        TabItem(icon: "square.stack", title: ""),
        TabItem(icon: "shippingbox", title: ""),
        TabItem(icon: "arrow.down.circle", title: ""),
        TabItem(icon: "gearshape", title: ""),
        TabItem(icon: "magnifyingglass", title: "")
    ]
    
    var body: some View {
        ZStack(alignment: .bottom) {
            switch selectedTab {
            case 0:
                LibraryView()
            case 1:
                SettingsViewModule()
            case 2:
                DownloadView()
            case 3:
                SettingsView()
            case 4:
                SearchView(searchQuery: $searchQuery)
            default:
                LibraryView()
            }
            
            TabBar(tabs: tabs, selectedTab: $selectedTab, lastTab: $lastTab, searchQuery: $searchQuery)
                .background {
                    ProgressiveBlurView()
                        .blur(radius: 10)
                        .padding(.horizontal, -20)
                        .padding(.bottom, -100)
                        .padding(.top, -10)
                }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
        .ignoresSafeArea(.keyboard, edges: .bottom)
        .padding(.bottom, -20)
    }
}

