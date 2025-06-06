//
//  SettingsViewAbout.swift
//  Sulfur
//
//  Created by Francesco on 26/05/25.
//

import SwiftUI
import Kingfisher
import AVKit
import WebKit

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
            
            content
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
    @State private var isAnimating = false
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                SettingsSection(title: "App Info", footer: "Sora/Sulfur will always remain free with no ADs!") {
                    HStack(alignment: .center, spacing: 16) {
                        KFImage(URL(string: "https://raw.githubusercontent.com/cranci1/Sora/refs/heads/dev/Sora/Assets.xcassets/AppIcons/AppIcon_Default.appiconset/darkmode.png"))
                            .placeholder {
                                ProgressView()
                            }
                            .resizable()
                            .frame(width: 100, height: 100)
                            .cornerRadius(20)
                            .shadow(radius: 5)
                        
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
                }
                
                SettingsSection(title: "Main Developer") {
                    Button(action: {
                        if let url = URL(string: "https://github.com/cranci1") {
                            UIApplication.shared.open(url)
                        }
                    }) {
                        ZStack(alignment: .trailing) {
                            KFImage(URL(string: "https://github.com/50n50/assets/blob/main/asset2.png?raw=true")!)
                                .placeholder {
                                    ProgressView()
                                }
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(height: 64)
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                            
                            HStack {
                                KFImage(URL(string: "https://avatars.githubusercontent.com/u/100066266?v=4"))
                                    .placeholder {
                                        ProgressView()
                                    }
                                    .resizable()
                                    .frame(width: 40, height: 40)
                                    .clipShape(Circle())
                                
                                AnimatedText(
                                    text: "cranci1",
                                    primaryColor: Color(hexTwo: "#41127b"),
                                    secondaryColor: Color(hexTwo: "#a78bda")
                                )
                                
                                Spacer()
                                Image(systemName: "safari")
                                    .foregroundColor(.indigo)
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 12)
                        }
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
    @State private var isAnimating = false

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
                    Button(action: {
                        if let url = URL(string: "https://github.com/\(contributor.login)") {
                            UIApplication.shared.open(url)
                        }
                    }) {
                        ZStack(alignment: .trailing) {
                            if contributor.login == "50n50" {
                                GifImageView(url: URL(string: "https://raw.githubusercontent.com/50n50/assets/refs/heads/main/asset1.gif")!)
                                    .frame(height: 64)
                                    .clipShape(RoundedRectangle(cornerRadius: 8))
                            } else if contributor.login == "xibrox" {
                                KFImage(URL(string: "https://raw.githubusercontent.com/50n50/assets/refs/heads/main/asset3.png")!)
                                    .placeholder {
                                        ProgressView()
                                    }
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                                    .frame(height: 64)
                                    .clipShape(RoundedRectangle(cornerRadius: 8))
                            } else if contributor.login == "Seeike" {
                                KFImage(URL(string: "https://raw.githubusercontent.com/50n50/assets/refs/heads/main/asset4.png")!)
                                    .placeholder {
                                        ProgressView()
                                    }
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                                    .frame(height: 64)
                                    .clipShape(RoundedRectangle(cornerRadius: 8))
                            } else if contributor.login == "realdoomsboygaming" {
                                KFImage(URL(string: "https://raw.githubusercontent.com/50n50/assets/refs/heads/main/asset5.png")!)
                                    .placeholder {
                                        ProgressView()
                                    }
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                                    .frame(height: 64)
                                    .clipShape(RoundedRectangle(cornerRadius: 8))
                            } else if contributor.login == "stormfjeld" {
                                KFImage(URL(string: "https://raw.githubusercontent.com/50n50/assets/refs/heads/main/asset6.png")!)
                                    .placeholder {
                                        ProgressView()
                                    }
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 64, alignment: .top)
                                    .clipped()
                                    .clipShape(RoundedRectangle(cornerRadius: 8))
                            } else if contributor.login == "bshar1865" {
                                KFImage(URL(string: "https://raw.githubusercontent.com/50n50/assets/refs/heads/main/asset7.png")!)
                                    .placeholder {
                                        ProgressView()
                                    }
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                                    .frame(height: 64)
                                    .clipShape(RoundedRectangle(cornerRadius: 8))
                            } else if contributor.login == "ordzy" {
                                KFImage(URL(string: "https://raw.githubusercontent.com/50n50/assets/refs/heads/main/asset8.png")!)
                                    .placeholder {
                                        ProgressView()
                                    }
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                                    .frame(height: 64)
                                    .clipShape(RoundedRectangle(cornerRadius: 8))
                            }
                            
                            HStack {
                                KFImage(URL(string: contributor.avatarUrl))
                                    .placeholder {
                                        ProgressView()
                                    }
                                    .resizable()
                                    .frame(width: 40, height: 40)
                                    .clipShape(Circle())
                                
                                if contributor.login == "50n50" {
                                    AnimatedText(
                                        text: contributor.login,
                                        primaryColor: Color(hexTwo: "#fa4860"),
                                        secondaryColor: Color(hexTwo: "#fccdd1")
                                    )
                                } else if contributor.login == "xibrox" {
                                    AnimatedText(
                                        text: contributor.login,
                                        primaryColor: .black,
                                        secondaryColor: Color(hexTwo: "#ff0000")
                                    )
                                } else if contributor.login == "Seeike" {
                                    AnimatedText(
                                        text: contributor.login,
                                        primaryColor: Color(hexTwo: "#34435E"),
                                        secondaryColor: Color(hexTwo: "#5d77ab")
                                    )
                                } else if contributor.login == "realdoomsboygaming" {
                                    AnimatedText(
                                        text: contributor.login,
                                        primaryColor: Color(hexTwo: "#ff0000"),
                                        secondaryColor: Color(hexTwo: "#ffa500")
                                    )
                                } else if contributor.login == "stormfjeld" {
                                    AnimatedText(
                                        text: contributor.login,
                                        primaryColor: .gray.opacity(0.7),
                                        secondaryColor: .white
                                    )
                                } else if contributor.login == "bshar1865" {
                                    AnimatedText(
                                        text: contributor.login,
                                        primaryColor: .gray.opacity(0.7),
                                        secondaryColor: .white
                                    )
                                } else if contributor.login == "ordzy" {
                                    AnimatedText(
                                        text: contributor.login,
                                        primaryColor: Color(hexTwo: "#cfc4c5"),
                                        secondaryColor: Color(hexTwo: "#38629d")
                                    )
                                } else {
                                    Text(contributor.login)
                                        .font(.headline)
                                        .foregroundColor(
                                            contributor.login == "IBH-RAD" ? Color(hexTwo: "#41127b") :
                                            .accentColor
                                        )
                                }
                                
                                Spacer()
                                Image(systemName: "safari")
                                    .foregroundColor(.accentColor)
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 12)
                        }
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
                }
                .padding(.vertical, 4)
            }
        }
        .onAppear {
            if contributors.isEmpty {
                loadContributors()
            }
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

struct AnimatedText: View {
    let text: String
    let primaryColor: Color
    let secondaryColor: Color
    @State private var isAnimating = false
    
    var body: some View {
        Text(text)
            .font(.headline)
            .foregroundStyle(
                LinearGradient(
                    colors: [
                        primaryColor,
                        secondaryColor,
                        primaryColor
                    ],
                    startPoint: isAnimating ? .trailing : .leading,
                    endPoint: isAnimating ? .leading : .trailing
                )
            )
            .onAppear {
                withAnimation(.linear(duration: 2.0).repeatForever(autoreverses: false)) {
                    isAnimating = true
                }
            }
            .onDisappear {
                isAnimating = false
            }
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

struct GifImageView: UIViewRepresentable {
    let url: URL
    @State private var cachedURL: URL?
    
    func makeUIView(context: Context) -> WKWebView {
        let webView = WKWebView()
        webView.scrollView.isScrollEnabled = false
        webView.isOpaque = false
        webView.backgroundColor = UIColor.clear
        return webView
    }
    
    func updateUIView(_ webView: WKWebView, context: Context) {
        KingfisherManager.shared.retrieveImage(with: url) { result in
            switch result {
            case .success(let imageResult):
                if let cachedURL = imageResult.cacheType == .memory || imageResult.cacheType == .disk ? 
                    KingfisherManager.shared.cache.cachePath(forKey: url.absoluteString) : nil {
                    let request = URLRequest(url: URL(fileURLWithPath: cachedURL))
                    webView.load(request)
                } else {
                    let request = URLRequest(url: url)
                    webView.load(request)
                }
            case .failure:
                let request = URLRequest(url: url)
                webView.load(request)
            }
        }
    }
}
