//
//  ProfileView.swift
//  Sulfur
//
//  Created by Dominic on 20.04.25.
//

import SwiftUI

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
                        .foregroundColor(.primary)
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

struct SettingsViewProfile: View {
    @EnvironmentObject var profileStore: ProfileStore

    @State private var showDeleteAlert = false
    @State private var profileIDToRemove: UUID?

    var body: some View {
        Form {
            Section(header: Text("Select Profile")) {
                ForEach(profileStore.profiles) { profile in
                    Button {
                        profileStore.setCurrentProfile(profile)
                    } label: {
                        ProfileCell(profile: profile,
                            isSelected: profile.id == profileStore.currentProfile.id
                        )
                    }
                    .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                       if profileStore.profiles.count > 1 {
                           Button(role: .destructive) {
                               profileIDToRemove = profile.id
                               showDeleteAlert = true
                           } label: {
                               Label("Delete", systemImage: "trash")
                           }
                       }
                   }
                }
            }

            Section(header: Text("Edit Selected Profile")) {
                HStack {
                    Text("Avatar")
                    TextField("Avatar", text: Binding(
                        get: { profileStore.currentProfile.emoji },
                        set: { newValue in

                            // handle multi unicode emojis like "👨‍👩‍👧‍👦" or "🧙‍♂️"
                            let emoji = String(newValue
                                .trimmingCharacters(in: .whitespacesAndNewlines)
                                .prefix(2)
                            )

                            profileStore.editCurrentProfile(name: profileStore.currentProfile.name, emoji: emoji)
                        }
                    ))
                        .lineLimit(1)
                        .multilineTextAlignment(.trailing)
                        .frame(maxWidth: .infinity)
                }

                HStack {
                    Text("Name")
                    TextField("Name", text: Binding(
                        get: { profileStore.currentProfile.name },
                        set: { newValue in
                            profileStore.editCurrentProfile(name: newValue, emoji: profileStore.currentProfile.emoji)
                        }
                    ))
                        .lineLimit(1)
                        .multilineTextAlignment(.trailing)
                        .frame(maxWidth: .infinity)
                }

                if profileStore.profiles.count > 1 {
                    Button(action: {
                        profileIDToRemove = profileStore.currentProfile.id
                        showDeleteAlert = true
                    }) {
                        Text("Delete Selected Profile")
                            .fontWeight(.semibold)
                            .foregroundColor(.red)
                    }
                }
            }
        }
        .navigationTitle("Profiles")
        .alert(isPresented: $showDeleteAlert) {
            Alert(
                title: Text("Delete Profile"),
                message: Text("Are you sure you want to delete this profile? This action cannot be undone."),
                primaryButton: .destructive(Text("Delete")) {
                    profileStore.deleteProfile(removalID: profileIDToRemove)
                },
                secondaryButton: .cancel()
            )
        }
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button {
                    UIApplication.shared.dismissKeyboard(true)
                } label: {
                    Text("Done")
                        .foregroundColor(.accentColor)
                        .fontWeight(.semibold)
                }
            }

            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    profileStore.addProfile(name: String(localized: "New Profile"), emoji: "🧙‍♂️")
                } label: {
                    Image(systemName: "plus")
                        .foregroundColor(.accentColor)
                }
            }
        }
        .modifier(HideToolbarModifier())
    }
}
