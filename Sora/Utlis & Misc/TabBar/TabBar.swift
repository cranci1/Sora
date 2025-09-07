//
//  TabBar.swift
//  SoraPrototype
//
//  Created by Inumaki on 26/04/2025.
//

import SwiftUI
import Combine


extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        
        let r, g, b, a: UInt64
        switch hex.count {
        case 6:
            (r, g, b, a) = (int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF, 255)
        case 8:
            (r, g, b, a) = (int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF, int >> 24 & 0xFF)
        default:
            (r, g, b, a) = (1, 1, 1, 1)
        }
        
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}


struct TabBar: View {
    var tabs: [TabItem]
    @Binding var selectedTab: Int
    @State private var lastTab: Int = 0
    @State private var showSearch: Bool = false
    @State private var searchQuery: String = ""
    @FocusState private var keyboardFocus: Bool
    @State private var keyboardHidden: Bool = true
    @State private var searchLocked: Bool = false
    @State private var keyboardHeight: CGFloat = 0
    
    @GestureState private var isHolding: Bool = false
    @State private var dragOffset: CGFloat = 0
    @State private var isDragging: Bool = false
    @State private var dragTargetIndex: Int? = nil
    @State private var jellyScale: CGFloat = 1.0
    @State private var lastDragTranslation: CGFloat = 0
    @State private var previousDragOffset: CGFloat = 0
    @State private var lastUpdateTime: Date = Date()
    @State private var capsuleOffset: CGFloat = 0
    
    private var gradientOpacity: CGFloat {
        let accentColor = UIColor(Color.accentColor)
        var white: CGFloat = 0
        accentColor.getWhite(&white, alpha: nil)
        return white > 0.5 ? 0.5 : 0.3
    }
    
    private var shouldSlideUp: Bool {
        return keyboardFocus && keyboardHeight > 100
    }
    
    @Namespace private var animation
    
    private let tabWidth: CGFloat = 70
    
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
                    Image(systemName: "xmark")
                        .font(.system(size: 20))
                        .foregroundStyle(.gray)
                        .frame(width: 20, height: 20)
                        .matchedGeometryEffect(id: "xmark", in: animation)
                        .padding(16)
                        .background(
                            Circle()
                                .fill(.ultraThinMaterial)
                                .overlay(
                                    Circle()
                                        .stroke(
                                            LinearGradient(
                                                gradient: Gradient(stops: [
                                                    .init(color: Color.accentColor.opacity(0.25), location: 0),
                                                    .init(color: Color.accentColor.opacity(0), location: 1)
                                                ]),
                                                startPoint: .top,
                                                endPoint: .bottom
                                            ),
                                            lineWidth: 0.5
                                        )
                                )
                                .matchedGeometryEffect(id: "background_circle", in: animation)
                        )
                }
                .disabled(!keyboardHidden || searchLocked)
            }
            HStack {
                if showSearch {
                    HStack {
                        Image(systemName: "magnifyingglass")
                            .font(.footnote)
                            .foregroundStyle(.gray)
                            .opacity(0.7)
                        
                        TextField("Search for something...", text: $searchQuery)
                            .textFieldStyle(.plain)
                            .font(.footnote)
                            .foregroundStyle(Color.accentColor)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .focused($keyboardFocus)
                            .onChange(of: keyboardFocus) { newValue in
                                withAnimation(.bouncy(duration: 0.3)) {
                                    keyboardHidden = !newValue
                                }
                            }
                            .onChange(of: searchQuery) { newValue in
                                NotificationCenter.default.post(
                                    name: .searchQueryChanged,
                                    object: nil,
                                    userInfo: ["searchQuery": newValue]
                                )
                            }
                            .onDisappear {
                                keyboardFocus = false
                            }
                        
                        if !searchQuery.isEmpty {
                            Button(action: {
                                searchQuery = ""
                            }) {
                                Image(systemName: "xmark.circle.fill")
                                    .font(.system(size: 16))
                                    .foregroundStyle(.gray)
                                    .opacity(0.7)
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                    }
                    .frame(height: 24)
                    .padding(8)
                } else {
                    ZStack(alignment: .leading) {
                        let isActuallyMoving = abs(jellyScale - 1.0) > 0.01
                        Capsule()
                            .fill(.white)
                            .shadow(color: .black.opacity(0.2), radius: 6)
                            .frame(width: tabWidth, height: 44)
                            .scaleEffect(x: isActuallyMoving ? jellyScale : 1.0, y: isActuallyMoving ? (2.0 - jellyScale) : 1.0, anchor: .center)
                            .scaleEffect(isDragging || isHolding ? 1.15 : 1.0)
                            .offset(x: capsuleOffset)
                            .zIndex(1)
                        let capsuleIndex: Int = isDragging ? Int(round(dragOffset / tabWidth)) : selectedTab
                        HStack(spacing: 0) {
                            ForEach(0..<tabs.count, id: \ .self) { index in
                                let tab = tabs[index]
                                let shouldEnlarge = isDragging && index == capsuleIndex
                                let isSelected = (index == selectedTab)
                                let isActive = (isDragging && index == capsuleIndex) || (!isDragging && index == selectedTab)
                                if selectedTab == index {
                                    tabButton(for: tab, index: index, scale: shouldEnlarge ? 1.35 : 1.0, isActive: isActive, isSelected: isSelected)
                                        .frame(width: tabWidth, height: 44)
                                        .contentShape(Rectangle())
                                        .gesture(
                                            DragGesture(minimumDistance: 0)
                                                .onChanged { value in
                                                    if !isDragging {
                                                        dragOffset = CGFloat(selectedTab) * tabWidth
                                                        capsuleOffset = dragOffset
                                                        isDragging = true
                                                        dragTargetIndex = selectedTab
                                                    }
                                                    if isDragging && selectedTab == index {
                                                        let now = Date()
                                                        let dt = now.timeIntervalSince(lastUpdateTime)
                                                        lastDragTranslation = value.translation.width
                                                        let totalWidth = tabWidth * CGFloat(tabs.count)
                                                        let startX = CGFloat(selectedTab) * tabWidth
                                                        let newOffset = startX + value.translation.width
                                                        dragOffset = min(max(newOffset, 0), totalWidth - tabWidth)
                                                        capsuleOffset = dragOffset
                                                        dragTargetIndex = dragTargetIndex(selectedTab: selectedTab, dragOffset: dragOffset, tabCount: tabs.count, tabWidth: tabWidth)
                                                        var velocity: CGFloat = 0
                                                        if dt > 0 {
                                                            velocity = (dragOffset - previousDragOffset) / CGFloat(dt)
                                                        }
                                                        let absVelocity = abs(velocity)
                                                        let scaleX = min(1.0 + min(absVelocity / 1200, 0.18), 1.18)
                                                        withAnimation(.interpolatingSpring(stiffness: 200, damping: 18)) {
                                                            jellyScale = scaleX
                                                        }
                                                        previousDragOffset = dragOffset
                                                        lastUpdateTime = now
                                                    }
                                                }
                                                .onEnded { value in
                                                    if isDragging && selectedTab == index {
                                                        previousDragOffset = 0
                                                        lastUpdateTime = Date()
                                                        lastDragTranslation = 0
                                                        let totalWidth = tabWidth * CGFloat(tabs.count)
                                                        let startX = CGFloat(selectedTab) * tabWidth
                                                        let newOffset = startX + value.translation.width
                                                        let target = dragTargetIndex(selectedTab: selectedTab, dragOffset: newOffset, tabCount: tabs.count, tabWidth: tabWidth)
                                                        withAnimation(.interpolatingSpring(stiffness: 110, damping: 19)) {
                                                            selectedTab = target
                                                            jellyScale = 1.0
                                                            capsuleOffset = CGFloat(target) * tabWidth
                                                        }
                                                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.32) {
                                                            dragOffset = 0
                                                            isDragging = false
                                                            dragTargetIndex = nil
                                                            capsuleOffset = CGFloat(selectedTab) * tabWidth
                                                        }
                                                        if target == tabs.count - 1 {
                                                            searchLocked = true
                                                            withAnimation(.bouncy(duration: 0.3)) {
                                                                lastTab = index
                                                                showSearch = true
                                                            }
                                                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                                                                searchLocked = false
                                                            }
                                                        }
                                                    }
                                                }
                                        )
                                } else {
                                    tabButton(for: tab, index: index, scale: shouldEnlarge ? 1.35 : 1.0, isActive: isActive, isSelected: isSelected)
                                        .frame(width: tabWidth, height: 44)
                                        .contentShape(Rectangle())
                                }
                            }
                        }
                        .zIndex(2)
                        .animation(.spring(response: 0.25, dampingFraction: 0.7), value: isDragging)
                    }
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                Capsule()
                    .fill(.ultraThinMaterial)
            )
            .clipShape(Capsule())
            .overlay(
                Capsule()
                    .strokeBorder(
                        LinearGradient(
                            gradient: Gradient(stops: [
                                .init(color: Color.accentColor.opacity(0.25), location: 0),
                                .init(color: Color.accentColor.opacity(0), location: 1)
                            ]),
                            startPoint: .top,
                            endPoint: .bottom
                        ),
                        lineWidth: 0.5
                    )
            )
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 20)
        .background {
            ProgressiveBlurView()
                .blur(radius: 10)
                .padding(.horizontal, -20)
                .padding(.bottom, -100)
                .padding(.top, -10)
        }
        .offset(y: shouldSlideUp ? -keyboardHeight + 40 : 0)
        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: shouldSlideUp)
        .onChange(of: keyboardHeight) { newValue in
            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
            }
        }
        .onAppear {
            capsuleOffset = CGFloat(selectedTab) * tabWidth
            NotificationCenter.default.addObserver(forName: UIResponder.keyboardWillShowNotification, object: nil, queue: .main) { notification in
                if let keyboardFrame = notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect {
                    keyboardHeight = keyboardFrame.height
                }
            }
            
            NotificationCenter.default.addObserver(forName: UIResponder.keyboardWillHideNotification, object: nil, queue: .main) { _ in
                keyboardHeight = 0
            }
            
            NotificationCenter.default.addObserver(forName: .tabBarSearchQueryUpdated, object: nil, queue: .main) { notification in
                if let query = notification.userInfo?["searchQuery"] as? String {
                    searchQuery = query
                }
            }
        }
        .onDisappear {
            NotificationCenter.default.removeObserver(self, name: UIResponder.keyboardWillShowNotification, object: nil)
            NotificationCenter.default.removeObserver(self, name: UIResponder.keyboardWillHideNotification, object: nil)
            NotificationCenter.default.removeObserver(self, name: .tabBarSearchQueryUpdated, object: nil)
        }
        .onChange(of: selectedTab) { newValue in
            if !isDragging {
                withAnimation(.interpolatingSpring(stiffness: 320, damping: 22)) {
                    capsuleOffset = CGFloat(newValue) * tabWidth
                }
            }
        }
    }
    
    @ViewBuilder
    private func tabButton(for tab: TabItem, index: Int, scale: CGFloat = 1.0, isActive: Bool, isSelected: Bool) -> some View {
        let icon = Image(systemName: tab.icon + (isActive ? ".fill" : ""))
            .frame(width: 28, height: 28)
            .matchedGeometryEffect(id: tab.icon, in: animation)
            .foregroundStyle(isActive ? .black : .gray)
            .padding(.vertical, 8)
            .padding(.horizontal, 10)
            .frame(width: tabWidth)
            .opacity(isActive ? 1 : 0.5)
            .scaleEffect(scale)
        
        icon
            .contentShape(Rectangle())
            .simultaneousGesture(
                TapGesture()
                    .onEnded {
                        if isDragging || isHolding { return }
            if index == tabs.count - 1 {
                searchLocked = true
                withAnimation(.bouncy(duration: 0.3)) {
                    lastTab = selectedTab
                    selectedTab = index
                    showSearch = true
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    searchLocked = false
                }
            } else {
                if (!searchLocked) {
                    withAnimation(.bouncy(duration: 0.3)) {
                        lastTab = selectedTab
                        selectedTab = index
                                }
                            }
                        }
                    }
            )
    }
    
    private func enlargedTabIndex(selectedTab: Int, dragOffset: CGFloat, tabCount: Int, tabWidth: CGFloat) -> Int {
        let index = Int(round(dragOffset / tabWidth))
        return min(max(index, 0), tabCount - 1)
    }

    private func dragTargetIndex(selectedTab: Int, dragOffset: CGFloat, tabCount: Int, tabWidth: CGFloat) -> Int {
        let index = Int(round(dragOffset / tabWidth))
        return min(max(index, 0), tabCount - 1)
    }
}
