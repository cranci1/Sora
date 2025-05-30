//
//  TabBar.swift
//  SoraPrototype
//
//  Created by Inumaki on 26/04/2025.
//

import SwiftUI


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
    let tabs: [TabItem]
    @Binding var selectedTab: Int
    @Binding var lastTab: Int
    @State var showSearch: Bool = false
    @FocusState var keyboardFocus: Bool
    @State var keyboardHidden: Bool = true
    @Binding var searchQuery: String
    @ObservedObject var controller: TabBarController
    
    @State private var keyboardHeight: CGFloat = 0
    
    private var gradientOpacity: CGFloat {
        let accentColor = UIColor(Color.accentColor)
        var white: CGFloat = 0
        accentColor.getWhite(&white, alpha: nil)
        return white > 0.5 ? 0.5 : 0.3
    }
    
    @Namespace private var animation
    
    
    func slideDown() {
        controller.hideTabBar()
    }
    
    func slideUp() {
        controller.showTabBar()
    }
    
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
                    Image(systemName: "x.circle")
                        .font(.system(size: 30))
                        .foregroundStyle(.gray)
                        .frame(width: 24, height: 24)
                        .matchedGeometryEffect(id: "x.circle", in: animation)
                        .padding(16)
                        .background(
                            Circle()
                                .fill(.ultraThinMaterial)
                                .overlay(
                                    Circle()
                                        .stroke(
                                            LinearGradient(
                                                gradient: Gradient(stops: [
                                                    .init(color: Color.accentColor.opacity(gradientOpacity), location: 0),
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
                .disabled(!keyboardHidden)
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
                            .onDisappear {
                                keyboardFocus = false
                            }
                    }
                    .frame(height: 24)
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
                                .init(color: Color.accentColor.opacity(gradientOpacity), location: 0),
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
            // Move the blur background here and animate it
            ProgressiveBlurView()
                .blur(radius: 10)
                .padding(.horizontal, -20)
                .padding(.bottom, -100)
                .padding(.top, -10)
                .opacity(controller.isHidden ? 0 : 1)  // Animate opacity
                .animation(.easeInOut(duration: 0.15), value: controller.isHidden)
        }
        .offset(y: controller.isHidden ? 120 : (keyboardFocus ? -keyboardHeight + 36 : 0))
        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: keyboardHeight)
        .animation(.easeInOut(duration: 0.15), value: controller.isHidden)
        .onChange(of: keyboardHeight) { newValue in
            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
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
                    .foregroundStyle(selectedTab == index ? .black : .gray)
                    .padding(.vertical, 8)
                    .padding(.horizontal, 10)
                    .frame(maxWidth: .infinity)
                    .opacity(selectedTab == index ? 1 : 0.5)
            } else {
                VStack {
                    Image(systemName: tab.icon + (selectedTab == index ? ".fill" : ""))
                        .frame(width: 36, height: 18)
                        .matchedGeometryEffect(id: tab.icon, in: animation)
                        .foregroundStyle(selectedTab == index ? .black : .gray)
                    
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
                .fill(.white)
                .shadow(color: .black.opacity(0.2), radius: 6)
                .matchedGeometryEffect(id: "background_capsule", in: animation)
            : nil
        )
    }
}
