//
//  ProfileView.swift
//  Sulfur
//
//  Created by Dominic on 20.04.25.
//
import SwiftUI

struct Profile: Identifiable, Equatable, Codable {
    var id: UUID = UUID()
    var name: String
    var emoji: String
}

struct ProfileCell: View {
    let profile: Profile
    var isSelected: Bool = false

    var body: some View {
        HStack(spacing: 10) {
            Circle()
                .fill(Color.secondary.opacity(0.3))
                .frame(width: 50, height: 50)
                .overlay(
                    Text(profile.emoji)
                        .font(.system(size: 28))
                )

            Text(profile.name)
                .font(.headline)
                .foregroundColor(.primary)

            Spacer()

            if isSelected {
                Image(systemName: "checkmark")
                    .foregroundColor(.accentColor)
            }
        }
        .padding(.vertical, 4)
    }
}


// TODO: add persistence
// TODO: filter media and modules by profile
// TODO: tests
struct SettingsViewProfile: View {
    @State private var currentProfile = Profile(name: "undeaD_D", emoji: "👤")
    @State private var profiles: [Profile] = [
        Profile(name: "undeaD_D", emoji: "👤"),
        Profile(name: "PlayerTwo", emoji: "🧑‍🚀")
    ]
    
    var body: some View {
        Form {
            Section(header: Text("Edit Current Profile")) {
                HStack {
                    Text("Image")
                    Spacer()
                    TextField("Emoji", text: $currentProfile.emoji)
                        .multilineTextAlignment(.trailing)
                        .frame(width: 50)
                }
                
                HStack {
                    Text("Name")
                    Spacer()
                    TextField("Name", text: $currentProfile.name)
                        .multilineTextAlignment(.trailing)
                }
            }
            
            Section(header: Text("Select Current Profile")) {
                ForEach(profiles) { profile in
                    Button {
                        currentProfile = profile
                    } label: {
                        ProfileCell(profile: profile, isSelected: profile == currentProfile)
                    }
                }
            }
        }
        .navigationTitle("Profile")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    let newProfile = Profile(name: "New Profile", emoji: "🧙‍♂️")
                    profiles.append(newProfile)
                    currentProfile = newProfile
                } label: {
                    Image(systemName: "plus")
                        .foregroundColor(.accentColor)
                }
            }
        }
    }
}
