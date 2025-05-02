//
//  ProfileStore.swift
//  Sulfur
//
//  Created by Dominic on 21.04.25.
//

import SwiftUI

class ProfileStore: ObservableObject {
    @AppStorage("profilesData") private var profilesData = Data()
    @AppStorage("currentProfileID") private var currentProfileID = ""

    @Published var profiles: [Profile] = []
    @Published var currentProfile: Profile!

    init() {
        profiles = (try? JSONDecoder().decode([Profile].self, from: profilesData)) ?? []

        if profiles.isEmpty {
            // load default value
            let defaultProfile = Profile(name: String(localized: "Default User"), emoji: "👤")
            profiles = [defaultProfile]

            saveProfiles()
            setCurrentProfile(defaultProfile)
        } else {
            // load current profile
            if let uuid = UUID(uuidString: currentProfileID),
               let match = profiles.first(where: { $0.id == uuid }) {
                currentProfile = match
            } else if let firstProfile = profiles.first {
                currentProfile = firstProfile
            } else {
                fatalError("profiles Array is not empty, but no profile was found")
            }
        }
    }

    func getUserDefaultsSuite() -> UserDefaults {
        guard let suite = UserDefaults(suiteName: currentProfile.id.uuidString) else {
            fatalError("This can only fail if suiteName == app bundle id ...")
        }

        Logger.shared.log("loaded UserDefaults suite for '\(currentProfile.name)'", type: .info)

        return suite
    }

    private func saveProfiles() {
        profilesData = (try? JSONEncoder().encode(profiles)) ?? Data()
    }

    func setCurrentProfile(_ profile: Profile) {
        currentProfile = profile
        currentProfileID = profile.id.uuidString
    }

    func addProfile(name: String, emoji: String) {
        let newProfile = Profile(name: name, emoji: emoji)
        profiles.append(newProfile)

        saveProfiles()
        setCurrentProfile(newProfile)
    }

    func editCurrentProfile(name: String, emoji: String) {
        guard let index = profiles.firstIndex(where: { $0.id == currentProfile.id }) else { return }
        profiles[index].name = name
        profiles[index].emoji = emoji

        saveProfiles()
        setCurrentProfile(profiles[index])
    }

    func deleteProfile(removalID: UUID?) {
        guard let removalID,
              profiles.count > 1
            else { return }

        if let suite = UserDefaults(suiteName: removalID.uuidString) {
            for key in suite.dictionaryRepresentation().keys {
                suite.removeObject(forKey: key)
            }
        }

        profiles.removeAll { $0.id == removalID }

        if let firstProfile = profiles.first {
            saveProfiles()
            setCurrentProfile(firstProfile)
        } else {
            fatalError("There should still be one Profile left")
        }
    }
}
