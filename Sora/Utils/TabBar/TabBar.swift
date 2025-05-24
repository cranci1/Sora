//
//  TabBar.swift
//  SoraPrototype
//
//  Created by Inumaki on 26/04/2025.
//

import SwiftUI

struct TabBar: View {
    let tabs: [TabItem]
    @Binding var selectedTab: Int
    @Binding var lastTab: Int
    @State var showSearch: Bool = false
    @FocusState var keyboardFocus: Bool
    @State var keyboardHidden: Bool = true
    @Binding var searchQuery: String
    
    @State private var keyboardHeight: CGFloat = 0
    
    @Namespace private var animation
    
    var body: some View {
        HStack {
            if showSearch && keyboardHidden {
                Button(action: {
                    keyboardFocus = false
                    withAnimation(.bouncy(duration: 0.3)) {
                        selectedTab = lastTab
                        showSearch = false
                    }
                }) {
                    Image(systemName: tabs[lastTab].icon + ".fill")
                        .foregroundStyle(.black)
                        .frame(width: 24, height: 24)
                        .matchedGeometryEffect(id: tabs[lastTab].icon, in: animation)
                        .padding(16)
                        .background(
                            Circle()
                                .fill(.ultraThinMaterial)
                                .matchedGeometryEffect(id: "background_circle", in: animation)
                        )
                }
                .disabled(!keyboardHidden)
            }
            
            HStack {
                if showSearch {
                    HStack {
                        Image(systemName: "magnifyingglass")
                            .font(.footnote)
                            .foregroundStyle(.black)
                            .opacity(0.7)
                        
                        TextField("Search for something...", text: $searchQuery)
                            .textFieldStyle(.plain)
                            .font(.footnote)
                            .foregroundStyle(.black)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .focused($keyboardFocus)
                            .onChange(of: keyboardFocus) { newValue in
                                withAnimation(.bouncy(duration: 0.3)) {
                                    keyboardHidden = !newValue
                                }
                            }
                            .onDisappear {
                                keyboardFocus = false
                            }
                    }
                    .padding(8)
                } else {
                    ForEach(0..<tabs.count, id: \.self) { index in
                        let tab = tabs[index]
                        
                        tabButton(for: tab, index: index)
                    }
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(.ultraThinMaterial)
            .clipShape(Capsule())
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 20)
        .offset(y: keyboardFocus ? -keyboardHeight + 36 : 0)
        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: keyboardHeight)
        .onChange(of: keyboardHeight) { newValue in
            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                // Animation will be handled by the offset modifier
            }
        }
        .onAppear {
            NotificationCenter.default.addObserver(forName: UIResponder.keyboardWillShowNotification, object: nil, queue: .main) { notification in
                if let keyboardFrame = notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect {
                    keyboardHeight = keyboardFrame.height
                }
            }
            
            NotificationCenter.default.addObserver(forName: UIResponder.keyboardWillHideNotification, object: nil, queue: .main) { _ in
                keyboardHeight = 0
            }
        }
    }
    
    @ViewBuilder
    private func tabButton(for tab: TabItem, index: Int) -> some View {
        Button(action: {
            if index == tabs.count - 1 {
                withAnimation(.bouncy(duration: 0.3)) {
                    lastTab = selectedTab
                    selectedTab = index
                    showSearch = true
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                        keyboardFocus = true
                    }
                }
            } else {
                withAnimation(.bouncy(duration: 0.3)) {
                    lastTab = selectedTab
                    selectedTab = index
                }
            }
        }) {
            if tab.title.isEmpty {
                Image(systemName: tab.icon + (selectedTab == index ? ".fill" : ""))
                    .frame(width: 28, height: 28)
                    .matchedGeometryEffect(id: tab.icon, in: animation)
                    .padding(.vertical, 8)
                    .padding(.horizontal, 10)
                    .frame(maxWidth: .infinity)
                    .opacity(selectedTab == index ? 1 : 0.5)
            } else {
                VStack {
                    Image(systemName: tab.icon + (selectedTab == index ? ".fill" : ""))
                        .frame(width: 36, height: 18)
                        .matchedGeometryEffect(id: tab.icon, in: animation)
                    
                    Text(tab.title)
                        .font(.caption)
                        .frame(width: 60)
                        .lineLimit(1)
                        .truncationMode(.tail)
                }
                .padding(.vertical, 8)
                .padding(.horizontal, 10)
                .frame(maxWidth: .infinity)
                .opacity(selectedTab == index ? 1 : 0.5)
            }
        }
        .background(
            selectedTab == index ?
            Capsule()
                .fill(Color.white)
                .shadow(color: .black.opacity(0.1), radius: 6)
                .matchedGeometryEffect(id: "background_capsule", in: animation)
            : nil
        )
    }
}
