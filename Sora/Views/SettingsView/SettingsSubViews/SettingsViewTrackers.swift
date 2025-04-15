//
//  SettingsViewTrackers.swift
//  Sora
//
//  Created by Francesco on 23/03/25.
//

import SwiftUI
import Security
import Kingfisher

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
        Form {
            Section(header: Text("AniList"), footer: Text("Sora and cranci1 are not affiliated with AniList in any way.\n\nNote that progresses update may not be 100% acurate.")) {
                HStack() {
                    KFImage(URL(string: "https://raw.githubusercontent.com/cranci1/Ryu/2f10226aa087154974a70c1ec78aa83a47daced9/Ryu/Assets.xcassets/Listing/Anilist.imageset/anilist.png"))
                        .placeholder {
                            RoundedRectangle(cornerRadius: 10)
                                .fill(Color.gray.opacity(0.3))
                                .frame(width: 80, height: 80)
                                .shimmering()
                        }
                        .resizable()
                        .frame(width: 80, height: 80)
                        .clipShape(Rectangle())
                        .cornerRadius(10)
                    Text("AniList.co")
                        .font(.title2)
                }
                
                if isAnilistLoading {
                    ProgressView()
                } else {
                    if isAnilistLoggedIn {
                        HStack(spacing: 0) {
                            Text("Logged in as ")
                            Text(anilistUsername)
                                .foregroundColor(profileColor)
                                .font(.body)
                                .fontWeight(.semibold)
                        }
                    } else {
                        Text(anilistStatus)
                            .multilineTextAlignment(.center)
                    }
                }
                
                if isAnilistLoggedIn {
                    Toggle("Sync anime progress", isOn: $isSendPushUpdates)
                        .tint(.accentColor)
                }
                
                Button(isAnilistLoggedIn ? "Log Out from AniList" : "Log In with AniList") {
                    if isAnilistLoggedIn {
                        logoutAniList()
                    } else {
                        loginAniList()
                    }
                }
                .font(.body)
            }
            
            Section(header: Text("Trakt"), footer: Text("Sora and cranci1 are not affiliated with Trakt in any way.\n\nNote that progress updates may not be 100% accurate.")) {
                HStack() {
                    KFImage(URL(string: "https://static-00.iconduck.com/assets.00/trakt-icon-2048x2048-2633ksxg.png"))
                        .placeholder {
                            RoundedRectangle(cornerRadius: 10)
                                .fill(Color.gray.opacity(0.3))
                                .frame(width: 80, height: 80)
                                .shimmering()
                        }
                        .resizable()
                        .frame(width: 80, height: 80)
                        .clipShape(Rectangle())
                        .cornerRadius(10)
                    Text("Trakt.tv")
                        .font(.title2)
                }
                
                if isTraktLoading {
                    ProgressView()
                } else {
                    if isTraktLoggedIn {
                        HStack(spacing: 0) {
                            Text("Logged in as ")
                            Text(traktUsername)
                                .font(.body)
                                .fontWeight(.semibold)
                        }
                    } else {
                        Text(traktStatus)
                            .multilineTextAlignment(.center)
                    }
                }
                
                if isTraktLoggedIn {
                    Toggle("Sync watch progress", isOn: $isSendTraktUpdates)
                        .tint(.accentColor)
                }
                
                Button(isTraktLoggedIn ? "Log Out from Trakt" : "Log In with Trakt") {
                    if isTraktLoggedIn {
                        logoutTrakt()
                    } else {
                        loginTrakt()
                    }
                }
                .font(.body)
            }
        }
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
