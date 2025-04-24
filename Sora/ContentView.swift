//
//  ContentView.swift
//  Sora
//
//  Created by Francesco on 06/01/25.
//

import SwiftUI
import Kingfisher

// Create a shared object to track scrolling state across views
class ScrollState: ObservableObject {
    @Published var hideTabBar = false
    
    static let shared = ScrollState()
}

struct ContentView: View {
    @State private var selectedTab: Tab = .library
    @Namespace private var animation
    @ObservedObject private var scrollState = ScrollState.shared

    enum Tab: String, CaseIterable {
        case library = "books.vertical"
        case search = "magnifyingglass"
        case settings = "gear"
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            Group {
                switch selectedTab {
                case .library:
                    LibraryView()
                        .transition(.move(edge: .trailing))
                case .search:
                    SearchView()
                        .transition(.move(edge: .trailing))
                case .settings:
                    SettingsView()
                        .transition(.move(edge: .trailing))
                }
            }
            .zIndex(1)
            .animation(.easeInOut(duration: 0.5), value: selectedTab)

            CustomTabBar(selectedTab: $selectedTab, animation: animation)
                .padding(.bottom, -25)
                .padding(.horizontal, 20)
                .offset(y: scrollState.hideTabBar ? 100 : 0)
                .animation(.spring(response: 0.3, dampingFraction: 0.7), value: scrollState.hideTabBar)
                .zIndex(2)
        }
        .ignoresSafeArea(.keyboard, edges: .bottom)
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                ScrollState.shared.hideTabBar = false
            }
        }
    }
}

struct CustomTabBar: View {
    @Binding var selectedTab: ContentView.Tab
    var animation: Namespace.ID
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        GeometryReader { geometry in
            let tabCount = ContentView.Tab.allCases.count
            let tabWidth = geometry.size.width / CGFloat(tabCount)
            HStack(spacing: 0) {
                ForEach(ContentView.Tab.allCases, id: \.self) { tab in
                    Button {
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                            selectedTab = tab
                        }
                    } label: {
                        Image(systemName: tab.rawValue)
                            .font(.system(size: 22, weight: .medium))
                            .frame(maxWidth: .infinity)
                            .foregroundColor(selectedTab == tab ? dynamicSelectedColor() : Color.gray) // Dynamic color for selected tab
                            .frame(height: 44)
                            .background(
                                ZStack {
                                    if selectedTab == tab {
                                        Circle()
                                            .fill(.ultraThinMaterial)
                                            .matchedGeometryEffect(id: "circle-\(tab.rawValue)", in: animation)
                                            .frame(width: 40, height: 44)
                                            .shadow(color: colorScheme == .dark ? Color(.label).opacity(0.1) : Color.black.opacity(0.2), radius: 3, x: 0, y: 2)
                                    }
                                }
                            )
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 10)
            .background(
                Capsule()
                    .fill(Color(.systemBackground).opacity(0.95))
                    .overlay(
                        Capsule()
                            .stroke(Color.secondary.opacity(0.2), lineWidth: 0.5)
                    )
                    .shadow(color: colorScheme == .dark ? Color(.label).opacity(0.1) : Color.black.opacity(0.15), radius: 5, x: 0, y: 2)
            )
            .frame(width: geometry.size.width)
        }
        .frame(height: 80)
    }

    private func dynamicSelectedColor() -> Color {
        if colorScheme == .dark {
            return .white
        } else {
            return .black 
        }
    }
}
