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
    
    @State private var status: String = "You are not logged in"
    @State private var isLoggedIn: Bool = false
    @State private var username: String = ""
    @State private var isLoading: Bool = false
    @State private var profileColor: Color = .accentColor
    
    var body: some View {
        Form {
            Section(header: Text("AniList"), footer: Text("Sora and cranci1 are not affiliated with AniList in any way.\n\nNote that push updates may not be 100% acurate.")) {
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
                if isLoading {
                    ProgressView()
                } else {
                    if isLoggedIn {
                        HStack(spacing: 0) {
                            Text("Logged in as ")
                            Text(username)
                                .foregroundColor(profileColor)
                                .font(.body)
                                .fontWeight(.semibold)
                        }
                    } else {
                        Text(status)
                            .multilineTextAlignment(.center)
                    }
                }
                if isLoggedIn {
                    Toggle("Send push updates", isOn: $isSendPushUpdates)
                        .tint(.accentColor)
                }
                Button(isLoggedIn ? "Log Out from AniList.co" : "Log In with AniList.co") {
                    if isLoggedIn {
                        logout()
                    } else {
                        login()
                    }
                }
                .font(.body)
            }
        }
        .navigationTitle("Trackers")
        .onAppear {
            updateStatus()
            setupNotificationObservers()
        }
        .onDisappear {
            removeNotificationObservers()
        }
    }
    
    func setupNotificationObservers() {
        NotificationCenter.default.addObserver(forName: AniListToken.authSuccessNotification, object: nil, queue: .main) { _ in
            self.status = "Authentication successful!"
            self.updateStatus()
        }
        
        NotificationCenter.default.addObserver(forName: AniListToken.authFailureNotification, object: nil, queue: .main) { notification in
            if let error = notification.userInfo?["error"] as? String {
                self.status = "Login failed: \(error)"
            } else {
                self.status = "Login failed with unknown error"
            }
            self.isLoggedIn = false
            self.isLoading = false
        }
    }
    
    func removeNotificationObservers() {
        NotificationCenter.default.removeObserver(self, name: AniListToken.authSuccessNotification, object: nil)
        NotificationCenter.default.removeObserver(self, name: AniListToken.authFailureNotification, object: nil)
    }
    
    func login() {
        status = "Starting authentication..."
        isLoading = true
        AniListLogin.authenticate()
    }
    
    func logout() {
        removeTokenFromKeychain()
        status = "You are not logged in"
        isLoggedIn = false
        username = ""
        profileColor = .primary
    }
    
    func updateStatus() {
        if let token = getTokenFromKeychain() {
            isLoggedIn = true
            fetchUserInfo(token: token)
        } else {
            isLoggedIn = false
            status = "You are not logged in"
        }
    }
    
    func fetchUserInfo(token: String) {
        isLoading = true
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
            status = "Failed to serialize request"
            Logger.shared.log("Failed to serialize request", type: "Error")
            isLoading = false
            return
        }
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            DispatchQueue.main.async {
                isLoading = false
                if let error = error {
                    status = "Error: \(error.localizedDescription)"
                    Logger.shared.log("Error: \(error.localizedDescription)", type: "Error")
                    return
                }
                guard let data = data else {
                    status = "No data received"
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
                        
                        username = name
                        profileColor = colorFromName(colorName)
                        status = "Logged in as \(name)"
                    } else {
                        status = "Unexpected response format!"
                        Logger.shared.log("Unexpected response format!", type: "Error")
                    }
                } catch {
                    status = "Failed to parse response: \(error.localizedDescription)"
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
