//
//  SettingsViewAbout.swift
//  Sulfur
//
//  Created by Francesco on 26/05/25.
//

import NukeUI
import SwiftUI

fileprivate struct SettingsSection<Content: View>: View {
    let title: String
    let footer: String?
    let content: Content
    
    init(title: String, footer: String? = nil, @ViewBuilder content: () -> Content) {
        self.title = title
        self.footer = footer
        self.content = content()
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title.uppercased())
                .font(.footnote)
                .foregroundStyle(.gray)
                .padding(.horizontal, 20)
            
            VStack(spacing: 0) {
                content
            }
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(
                        LinearGradient(
                            gradient: Gradient(stops: [
                                .init(color: Color.accentColor.opacity(0.3), location: 0),
                                .init(color: Color.accentColor.opacity(0), location: 1)
                            ]),
                            startPoint: .top,
                            endPoint: .bottom
                        ),
                        lineWidth: 0.5
                    )
            )
            .padding(.horizontal, 20)
            
            if let footer = footer {
                Text(footer)
                    .font(.footnote)
                    .foregroundStyle(.gray)
                    .padding(.horizontal, 20)
                    .padding(.top, 4)
            }
        }
    }
}

struct SettingsViewAbout: View {
    let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "ALPHA"
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                SettingsSection(title: "App Info", footer: "Sora/Sulfur will always remain free with no ADs!") {
                    HStack(alignment: .center, spacing: 16) {
                        LazyImage(url: URL(string: "https://raw.githubusercontent.com/cranci1/Sora/refs/heads/dev/Sora/Assets.xcassets/AppIcons/AppIcon_Default.appiconset/darkmode.png")) { state in
                            if let uiImage = state.imageContainer?.image {
                                Image(uiImage: uiImage)
                                    .resizable()
                                    .frame(width: 100, height: 100)
                                    .cornerRadius(20)
                                    .shadow(radius: 5)
                            } else {
                                ProgressView()
                                    .frame(width: 40, height: 40)
                            }
                        }
                        
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Sora")
                                .font(.title)
                                .bold()
                            Text("AKA Sulfur")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                }
                
                SettingsSection(title: "Main Developer") {
                    Button(action: {
                        if let url = URL(string: "https://github.com/cranci1") {
                            UIApplication.shared.open(url)
                        }
                    }) {
                        HStack {
                            LazyImage(url: URL(string: "https://avatars.githubusercontent.com/u/100066266?v=4")) { state in
                                if let uiImage = state.imageContainer?.image {
                                    Image(uiImage: uiImage)
                                        .resizable()
                                        .frame(width: 40, height: 40)
                                        .clipShape(Circle())
                                } else {
                                    ProgressView()
                                        .frame(width: 40, height: 40)
                                }
                            }
                            
                            VStack(alignment: .leading) {
                                Text("cranci1")
                                    .font(.headline)
                                    .foregroundColor(.indigo)
                                Text("me frfr")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }
                            Spacer()
                            Image(systemName: "safari")
                                .foregroundColor(.indigo)
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                    }
                }
                
                SettingsSection(title: "Contributors") {
                    ContributorsView()
                }
            }
            .padding(.vertical, 20)
        }
        .navigationTitle("About")
        .scrollViewBottomPadding()
    }
}

struct ContributorsView: View {
    @State private var contributors: [Contributor] = []
    @State private var isLoading = true
    @State private var error: Error?
    
    var body: some View {
        Group {
            if isLoading {
                HStack {
                    Spacer()
                    ProgressView()
                    Spacer()
                }
                .padding(.vertical, 12)
            } else if error != nil {
                Text("Failed to load contributors")
                    .foregroundColor(.secondary)
                    .padding(.vertical, 12)
            } else {
                ForEach(filteredContributors) { contributor in
                    ContributorView(contributor: contributor)
                    if contributor.id != filteredContributors.last?.id {
                        Divider()
                            .padding(.horizontal, 16)
                    }
                }
            }
        }
        .onAppear {
            loadContributors()
        }
    }
    
    private var filteredContributors: [Contributor] {
        contributors.filter { contributor in
            !["cranci1", "code-factor"].contains(contributor.login.lowercased())
        }
    }
    
    private func loadContributors() {
        let url = URL(string: "https://api.github.com/repos/cranci1/Sora/contributors")!
        
        URLSession.shared.dataTask(with: url) { data, response, error in
            DispatchQueue.main.async {
                isLoading = false
                
                if let error = error {
                    self.error = error
                    return
                }
                
                if let data = data {
                    do {
                        self.contributors = try JSONDecoder().decode([Contributor].self, from: data)
                    } catch {
                        self.error = error
                    }
                }
            }
        }.resume()
    }
}

struct ContributorView: View {
    let contributor: Contributor
    
    var body: some View {
        Button(action: {
            if let url = URL(string: "https://github.com/\(contributor.login)") {
                UIApplication.shared.open(url)
            }
        }) {
            HStack {
                LazyImage(url: URL(string: contributor.avatarUrl)) { state in
                    if let uiImage = state.imageContainer?.image {
                        Image(uiImage: uiImage)
                            .resizable()
                            .frame(width: 40, height: 40)
                            .clipShape(Circle())
                    } else {
                        ProgressView()
                            .frame(width: 40, height: 40)
                    }
                }
                
                Text(contributor.login)
                    .font(.headline)
                    .foregroundColor(
                        contributor.login == "IBH-RAD" ? Color(hexTwo: "#41127b") :
                        contributor.login == "50n50" ? Color(hexTwo: "#fa4860") :
                        .accentColor
                    )

                Spacer()
                Image(systemName: "safari")
                    .foregroundColor(.accentColor)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
    }
}

struct Contributor: Identifiable, Decodable {
    let id: Int
    let login: String
    let avatarUrl: String
    
    enum CodingKeys: String, CodingKey {
        case id
        case login
        case avatarUrl = "avatar_url"
    }
}

extension Color {
    init(hexTwo: String) {
        let hexTwo = hexTwo.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hexTwo).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hexTwo.count {
        case 3:
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6:
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8:
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (1, 1, 1, 0)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue:  Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}
