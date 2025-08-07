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
    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 24) {
                SettingsSection(title: "App Info", footer: "Sora/Sulfur will always remain free with no ads!") {
                    HStack(alignment: .center, spacing: 16) {
                        LazyImage(url: URL(string: "https://raw.githubusercontent.com/cranci1/Sora/refs/heads/dev/Sora/Assets.xcassets/AppIcon.appiconset/darkmode.png")) { state in
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
                            Text(LocalizedStringKey("Sora"))
                                .font(.title)
                                .bold()
                            Text(LocalizedStringKey("Also known as Sulfur"))
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
                                Text(LocalizedStringKey("cranci1"))
                                    .font(.headline)
                                    .foregroundColor(.indigo)
                                Text(LocalizedStringKey("me frfr"))
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
                
                SettingsSection(title: "Translators") {
                    TranslatorsView()
                }
            }
            .padding(.vertical, 20)
        }
        .navigationTitle(LocalizedStringKey("About"))
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
                Text(LocalizedStringKey("Failed to load contributors"))
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
        let realContributors = contributors.filter { contributor in
            !["cranci1", "code-factor"].contains(contributor.login.lowercased())
        }
        
        let artificialUsers = createArtificialUsers()
        
        return realContributors + artificialUsers
    }
    
    private func createArtificialUsers() -> [Contributor] {
        return [
            Contributor(
                id: 71751652,
                login: "qooode",
                avatarUrl: "https://avatars.githubusercontent.com/u/71751652?v=4"
            )
        ]
    }
    
    private func loadContributors() {
        let url = URL(string: "https://api.github.com/repos/cranci1/Sora/contributors")!
        
        URLSession.custom.dataTask(with: url) { data, response, error in
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
                        contributor.login == "CiroHoodLove" ? Color(hexTwo: "#940101") :
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

struct TranslatorsView: View {
    struct Translator: Identifiable {
        let id: Int
        let login: String
        let avatarUrl: String
        let language: String
    }

    private let translators: [Translator] = [
        Translator(
            id: 1,
            login: "paul", 
            avatarUrl: "https://github.com/50n50/assets/blob/main/pfps/54b3198dfb900837a9b8a7ec0b791add_webp.png?raw=true",
            language: "Dutch"
        ),
        Translator(
            id: 2,
            login: "Utopia",
            avatarUrl: "https://github.com/50n50/assets/blob/main/pfps/2b3b696895d5b7e708e3e5efaad62411_webp.png?raw=true",
            language: "Bosnian"
        ),
        Translator(
            id: 3,
            login: "simplymox",
            avatarUrl: "https://github.com/50n50/assets/blob/main/pfps/9131174855bd67fc445206e888505a6a_webp.png?raw=true",
            language: "Italian"
        ),
        Translator(
            id: 4,
            login: "ibro",
            avatarUrl: "https://github.com/50n50/assets/blob/main/pfps/05cd4f3508f99ba0a4ae2d0985c2f68c_webp.png?raw=true",
            language: "Russian, Czech, Kazakh"
        ),
        Translator(
            id: 5,
            login: "Ciro",
            avatarUrl: "https://github.com/50n50/assets/blob/main/pfps/4accfc2fcfa436165febe4cad18de978_webp.png?raw=true",
            language: "Arabic, French"
        ),
        Translator(
            id: 6,
            login: "storm",
            avatarUrl: "https://github.com/50n50/assets/blob/main/pfps/a6cc97f87d356523820461fd761fc3e1_webp.png?raw=true",
            language: "Norwegian, Swedish"
        ),
        Translator(
            id: 7,
            login: "VastSector0",
            avatarUrl: "https://github.com/50n50/assets/blob/main/pfps/bd8bccb82e0393b767bb705c4dc07113_webp.png?raw=true",
            language: "Spanish"
        ),
        Translator(
            id: 8,
            login: "Seiike",
            avatarUrl: "https://github.com/50n50/assets/blob/main/pfps/ca512dc4ce1f0997fd44503dce0a0fc8_webp.png?raw=true",
            language: "Slovak"
        ),
        Translator(
            id: 9,
            login: "Cufiy",
            avatarUrl: "https://github.com/50n50/assets/blob/main/pfps/y1wwm0ed_png.png?raw=true",
            language: "German"
        ),
        Translator(
            id: 10,
            login: "yoshi1780",
            avatarUrl: "https://github.com/50n50/assets/blob/main/pfps/262d7c1a61ff49355ddb74c76c7c5c7f_webp.png?raw=true",
            language: "Mongolian"
        ),
        Translator(
            id: 11,
            login: "Perju",
            avatarUrl: "https://github.com/50n50/assets/blob/main/pfps/82e3e7054935345b494e12ac33fd8e4f_webp.png?raw=true",
            language: "Romanian"
        )
    ]

    var body: some View {
        ForEach(translators) { translator in
            HStack {
                LazyImage(url: URL(string: translator.avatarUrl)) { state in
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
                VStack(alignment: .leading, spacing: 2) {
                    Text(translator.login)
                        .font(.headline)
                        .foregroundColor(.accentColor)
                    Text(translator.language)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            if translator.id != translators.last?.id {
                Divider()
                    .padding(.horizontal, 16)
            }
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
