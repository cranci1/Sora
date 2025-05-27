//
//  SettingsViewAbout.swift
//  Sulfur
//
//  Created by Francesco on 26/05/25.
//

import SwiftUI
import Kingfisher

struct SettingsViewAbout: View {
    let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "ALPHA"
    
    var body: some View {
        Form {
            Section(footer: Text("Sora/Sulfur will always remain free with no ADs!")) {
                HStack {
                    KFImage(URL(string: "https://raw.githubusercontent.com/cranci1/Sora/refs/heads/dev/Sora/Assets.xcassets/AppIcons/AppIcon_Default.appiconset/darkmode.png"))
                        .placeholder {
                            ProgressView()
                        }
                        .resizable()
                        .frame(width: 100, height: 100)
                        .cornerRadius(20)
                        .shadow(radius: 5)
                    
                    VStack(spacing: 8) {
                        Text("Sora")
                            .font(.title)
                            .bold()
                        Text("Version \(version)")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }
                .listRowInsets(EdgeInsets())
                .padding()
            }
            
            Section("Main Developer") {
                Button(action: {
                    if let url = URL(string: "https://github.com/cranci1") {
                        UIApplication.shared.open(url)
                    }
                }) {
                    HStack {
                        KFImage(URL(string: "https://avatars.githubusercontent.com/u/100066266?v=4"))
                            .placeholder {
                                ProgressView()
                            }
                            .resizable()
                            .frame(width: 40, height: 40)
                            .clipShape(Circle())
                        
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
                }
            }
            
            Section("Contributors") {
                ContributorsView()
            }
        }
        .navigationTitle("About")
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
            } else if error != nil {
                Text("Failed to load contributors")
                    .foregroundColor(.secondary)
            } else {
                ForEach(filteredContributors) { contributor in
                    ContributorView(contributor: contributor)
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
                KFImage(URL(string: contributor.avatarUrl))
                    .placeholder {
                        ProgressView()
                    }
                    .resizable()
                    .frame(width: 40, height: 40)
                    .clipShape(Circle())
                
                Text(contributor.login)
                    .font(.headline)
                    .foregroundColor(.accentColor)
                
                Spacer()
                Image(systemName: "safari")
                    .foregroundColor(.accentColor)
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