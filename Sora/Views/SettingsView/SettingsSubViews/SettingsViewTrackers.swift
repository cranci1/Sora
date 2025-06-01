//
//  SettingsViewTrackers.swift
//  Sora
//
//  Created by Francesco on 23/03/25.
//

import SwiftUI
import Security
import Kingfisher

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

fileprivate struct SettingsToggleRow: View {
    let icon: String
    let title: String
    @Binding var isOn: Bool
    var showDivider: Bool = true
    
    init(icon: String, title: String, isOn: Binding<Bool>, showDivider: Bool = true) {
        self.icon = icon
        self.title = title
        self._isOn = isOn
        self.showDivider = showDivider
    }
    
    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Image(systemName: icon)
                    .frame(width: 24, height: 24)
                    .foregroundStyle(.primary)
                
                Text(title)
                    .foregroundStyle(.primary)
                
                Spacer()
                
                Toggle("", isOn: $isOn)
                    .labelsHidden()
                    .tint(.accentColor.opacity(0.7))
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .frame(height: 48)
            
            if showDivider {
                Divider()
                    .padding(.horizontal, 16)
            }
        }
    }
}

struct SettingsViewTrackers: View {
    @AppStorage("sendPushUpdates") private var isSendPushUpdates = true
    @State private var anilistStatus: String = "You are not logged in"
    @State private var isAnilistLoggedIn: Bool = false
    @State private var anilistUsername: String = ""
    @State private var isAnilistLoading: Bool = false
    @State private var profileColor: Color = .accentColor
    
    @AppStorage("sendTraktUpdates") private var isSendTraktUpdates = true
    @State private var traktStatus: String = "You are not logged in"
    @State private var isTraktLoggedIn: Bool = false
    @State private var traktUsername: String = ""
    @State private var isTraktLoading: Bool = false
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                SettingsSection(title: "AniList") {
                    VStack(spacing: 0) {
                        HStack(alignment: .center, spacing: 10) {
                            KFImage(URL(string: "https://raw.githubusercontent.com/cranci1/Ryu/2f10226aa087154974a70c1ec78aa83a47daced9/Ryu/Assets.xcassets/Listing/Anilist.imageset/anilist.png"))
                                .placeholder {
                                    RoundedRectangle(cornerRadius: 10)
                                        .fill(Color.gray.opacity(0.3))
                                        .frame(width: 60, height: 60)
                                        .shimmering()
                                }
                                .resizable()
                                .frame(width: 60, height: 60)
                                .clipShape(Rectangle())
                                .cornerRadius(10)
                                .padding(.trailing, 10)
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text("AniList.co")
                                    .font(.title3)
                                    .fontWeight(.semibold)
                                
                                Group {
                                    if isAnilistLoading {
                                        ProgressView()
                                            .scaleEffect(0.8)
                                            .frame(height: 18)
                                    } else if isAnilistLoggedIn {
                                        HStack(spacing: 0) {
                                            Text("Logged in as ")
                                                .font(.footnote)
                                                .foregroundStyle(.gray)
                                            Text(anilistUsername)
                                                .font(.footnote)
                                                .fontWeight(.medium)
                                                .foregroundStyle(profileColor)
                                        }
                                        .frame(height: 18)
                                    } else {
                                        Text(anilistStatus)
                                            .font(.footnote)
                                            .foregroundStyle(.gray)
                                            .frame(height: 18)
                                    }
                                }
                            }
                            .frame(height: 60, alignment: .center)
                            
                            Spacer()
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .frame(height: 84)
                        
                        if isAnilistLoggedIn {
                            Divider()
                                .padding(.horizontal, 16)
                            
                            SettingsToggleRow(
                                icon: "arrow.triangle.2.circlepath",
                                title: "Sync anime progress",
                                isOn: $isSendPushUpdates,
                                showDivider: false
                            )
                        }
                        
                        Divider()
                            .padding(.horizontal, 16)
                        
                        Button(action: {
                            if isAnilistLoggedIn {
                                logoutAniList()
                            } else {
                                loginAniList()
                            }
                        }) {
                            HStack {
                                Image(systemName: isAnilistLoggedIn ? "rectangle.portrait.and.arrow.right" : "person.badge.key")
                                    .frame(width: 24, height: 24)
                                    .foregroundStyle(isAnilistLoggedIn ? .red : .accentColor)
                                
                                Text(isAnilistLoggedIn ? "Log Out from AniList" : "Log In with AniList")
                                    .foregroundStyle(isAnilistLoggedIn ? .red : .accentColor)
                                
                                Spacer()
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 12)
                            .frame(height: 48)
                        }
                    }
                }
                
                SettingsSection(title: "Trakt") {
                    VStack(spacing: 0) {
                        HStack(alignment: .center, spacing: 10) {
                            KFImage(URL(string: "https://static-00.iconduck.com/assets.00/trakt-icon-2048x2048-2633ksxg.png"))
                                .placeholder {
                                    RoundedRectangle(cornerRadius: 10)
                                        .fill(Color.gray.opacity(0.3))
                                        .frame(width: 60, height: 60)
                                        .shimmering()
                                }
                                .resizable()
                                .frame(width: 60, height: 60)
                                .clipShape(Rectangle())
                                .cornerRadius(10)
                                .padding(.trailing, 10)
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Trakt.tv")
                                    .font(.title3)
                                    .fontWeight(.semibold)
                                
                                Group {
                                    if isTraktLoading {
                                        ProgressView()
                                            .scaleEffect(0.8)
                                            .frame(height: 18)
                                    } else if isTraktLoggedIn {
                                        HStack(spacing: 0) {
                                            Text("Logged in as ")
                                                .font(.footnote)
                                                .foregroundStyle(.gray)
                                            Text(traktUsername)
                                                .font(.footnote)
                                                .fontWeight(.medium)
                                                .foregroundStyle(.primary)
                                        }
                                        .frame(height: 18)
                                    } else {
                                        Text(traktStatus)
                                            .font(.footnote)
                                            .foregroundStyle(.gray)
                                            .frame(height: 18)
                                    }
                                }
                            }
                            .frame(height: 60, alignment: .center)
                            
                            Spacer()
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .frame(height: 84)
                        
                        Divider()
                            .padding(.horizontal, 16)
                        
                        Button(action: {
                            if isTraktLoggedIn {
                                logoutTrakt()
                            } else {
                                loginTrakt()
                            }
                        }) {
                            HStack {
                                Image(systemName: isTraktLoggedIn ? "rectangle.portrait.and.arrow.right" : "person.badge.key")
                                    .frame(width: 24, height: 24)
                                    .foregroundStyle(isTraktLoggedIn ? .red : .accentColor)
                                
                                Text(isTraktLoggedIn ? "Log Out from Trakt" : "Log In with Trakt")
                                    .foregroundStyle(isTraktLoggedIn ? .red : .accentColor)
                                
                                Spacer()
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 12)
                            .frame(height: 48)
                        }
                    }
                }
                
                SettingsSection(
                    title: "Info",
                    footer: "Sora and cranci1 are not affiliated with AniList nor Trakt in any way.\n\nAlso note that progresses update may not be 100% accurate."
                ) {}
            }
            .padding(.vertical, 20)
        }
        .scrollViewBottomPadding()
        .navigationTitle("Trackers")
        .onAppear {
            updateAniListStatus()
            updateTraktStatus()
            setupNotificationObservers()
        }
        .onDisappear {
            removeNotificationObservers()
        }
    }
    
    func removeNotificationObservers() {
        NotificationCenter.default.removeObserver(self, name: AniListToken.authSuccessNotification, object: nil)
        NotificationCenter.default.removeObserver(self, name: AniListToken.authFailureNotification, object: nil)
        
        NotificationCenter.default.removeObserver(self, name: TraktToken.authSuccessNotification, object: nil)
        NotificationCenter.default.removeObserver(self, name: TraktToken.authFailureNotification, object: nil)
    }
    
    func setupNotificationObservers() {
        NotificationCenter.default.addObserver(forName: AniListToken.authSuccessNotification, object: nil, queue: .main) { _ in
            self.anilistStatus = "Authentication successful!"
            self.updateAniListStatus()
        }
        
        NotificationCenter.default.addObserver(forName: AniListToken.authFailureNotification, object: nil, queue: .main) { notification in
            if let error = notification.userInfo?["error"] as? String {
                self.anilistStatus = "Login failed: \(error)"
            } else {
                self.anilistStatus = "Login failed with unknown error"
            }
            self.isAnilistLoggedIn = false
            self.isAnilistLoading = false
        }
        
        NotificationCenter.default.addObserver(forName: TraktToken.authSuccessNotification, object: nil, queue: .main) { _ in
            self.traktStatus = "Authentication successful!"
            self.updateTraktStatus()
        }
        
        NotificationCenter.default.addObserver(forName: TraktToken.authFailureNotification, object: nil, queue: .main) { notification in
            if let error = notification.userInfo?["error"] as? String {
                self.traktStatus = "Login failed: \(error)"
            } else {
                self.traktStatus = "Login failed with unknown error"
            }
            self.isTraktLoggedIn = false
            self.isTraktLoading = false
        }
    }
    
    func loginTrakt() {
        traktStatus = "Starting authentication..."
        isTraktLoading = true
        TraktLogin.authenticate()
    }
    
    func logoutTrakt() {
        removeTraktTokenFromKeychain()
        traktStatus = "You are not logged in"
        isTraktLoggedIn = false
        traktUsername = ""
    }
    
    func updateTraktStatus() {
        if let token = getTraktTokenFromKeychain() {
            isTraktLoggedIn = true
            fetchTraktUserInfo(token: token)
        } else {
            isTraktLoggedIn = false
            traktStatus = "You are not logged in"
        }
    }
    
    func fetchTraktUserInfo(token: String) {
        isTraktLoading = true
        let userInfoURL = URL(string: "https://api.trakt.tv/users/settings")!
        var request = URLRequest(url: userInfoURL)
        request.httpMethod = "GET"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("2", forHTTPHeaderField: "trakt-api-version")
        request.setValue(TraktToken.clientID, forHTTPHeaderField: "trakt-api-key")
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            DispatchQueue.main.async {
                self.isTraktLoading = false
                if let error = error {
                    self.traktStatus = "Error: \(error.localizedDescription)"
                    return
                }
                
                guard let data = data else {
                    self.traktStatus = "No data received"
                    return
                }
                
                do {
                    if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                       let user = json["user"] as? [String: Any],
                       let username = user["username"] as? String {
                        self.traktUsername = username
                        self.traktStatus = "Logged in as \(username)"
                    }
                } catch {
                    self.traktStatus = "Failed to parse response"
                }
            }
        }.resume()
    }
    
    func getTraktTokenFromKeychain() -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: TraktToken.serviceName,
            kSecAttrAccount as String: TraktToken.accessTokenKey,
            kSecReturnData as String: kCFBooleanTrue!,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        
        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        guard status == errSecSuccess,
              let tokenData = item as? Data,
              let token = String(data: tokenData, encoding: .utf8) else {
                  return nil
              }
        return token
    }
    
    func removeTraktTokenFromKeychain() {
        let deleteQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: TraktToken.serviceName,
            kSecAttrAccount as String: TraktToken.accessTokenKey
        ]
        SecItemDelete(deleteQuery as CFDictionary)
        
        let refreshDeleteQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: TraktToken.serviceName,
            kSecAttrAccount as String: TraktToken.refreshTokenKey
        ]
        SecItemDelete(refreshDeleteQuery as CFDictionary)
    }
    
    func loginAniList() {
        anilistStatus = "Starting authentication..."
        isAnilistLoading = true
        AniListLogin.authenticate()
    }
    
    func logoutAniList() {
        removeTokenFromKeychain()
        anilistStatus = "You are not logged in"
        isAnilistLoggedIn = false
        anilistUsername = ""
        profileColor = .primary
    }
    
    func updateAniListStatus() {
        if let token = getTokenFromKeychain() {
            isAnilistLoggedIn = true
            fetchUserInfo(token: token)
        } else {
            isAnilistLoggedIn = false
            anilistStatus = "You are not logged in"
        }
    }
    
    func fetchUserInfo(token: String) {
        isAnilistLoading = true
        let userInfoURL = URL(string: "https://graphql.anilist.co")!
        var request = URLRequest(url: userInfoURL)
        request.httpMethod = "POST"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let query = """
        {
            Viewer {
                id
                name
                options {
                    profileColor
                }
            }
        }
        """
        let body: [String: Any] = ["query": query]
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: body, options: [])
        } catch {
            anilistStatus = "Failed to serialize request"
            Logger.shared.log("Failed to serialize request", type: "Error")
            isAnilistLoading = false
            return
        }
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            DispatchQueue.main.async {
                isAnilistLoading = false
                if let error = error {
                    anilistStatus = "Error: \(error.localizedDescription)"
                    Logger.shared.log("Error: \(error.localizedDescription)", type: "Error")
                    return
                }
                guard let data = data else {
                    anilistStatus = "No data received"
                    Logger.shared.log("No data received", type: "Error")
                    return
                }
                do {
                    if let json = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any],
                       let dataDict = json["data"] as? [String: Any],
                       let viewer = dataDict["Viewer"] as? [String: Any],
                       let name = viewer["name"] as? String,
                       let options = viewer["options"] as? [String: Any],
                       let colorName = options["profileColor"] as? String {
                        
                        anilistUsername = name
                        profileColor = colorFromName(colorName)
                        anilistStatus = "Logged in as \(name)"
                    } else {
                        anilistStatus = "Unexpected response format!"
                        Logger.shared.log("Unexpected response format!", type: "Error")
                    }
                } catch {
                    anilistStatus = "Failed to parse response: \(error.localizedDescription)"
                    Logger.shared.log("Failed to parse response: \(error.localizedDescription)", type: "Error")
                }
            }
        }.resume()
    }
    
    func colorFromName(_ name: String) -> Color {
        switch name.lowercased() {
        case "blue":
            return .blue
        case "purple":
            return .purple
        case "green":
            return .green
        case "orange":
            return .orange
        case "red":
            return .red
        case "pink":
            return .pink
        case "gray":
            return .gray
        default:
            return .accentColor
        }
    }
    
    func getTokenFromKeychain() -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: "me.cranci.sora.AniListToken",
            kSecAttrAccount as String: "AniListAccessToken",
            kSecReturnData as String: kCFBooleanTrue!,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        guard status == errSecSuccess, let tokenData = item as? Data else {
            return nil
        }
        return String(data: tokenData, encoding: .utf8)
    }
    
    func removeTokenFromKeychain() {
        let deleteQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: "me.cranci.sora.AniListToken",
            kSecAttrAccount as String: "AniListAccessToken"
        ]
        SecItemDelete(deleteQuery as CFDictionary)
    }
}
