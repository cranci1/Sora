//
//  LibraryManager.swift
//  Sora
//
//  Created by paul on 18/06/25.
//

import SwiftUI

struct CollectionPickerView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var libraryManager: LibraryManager
    let bookmark: LibraryItem
    @State private var newCollectionName: String = ""
    @State private var isShowingNewCollectionField: Bool = false
    
    var body: some View {
        NavigationView {
            List {
                if isShowingNewCollectionField {
                    Section {
                        HStack {
                            TextField("Collection name", text: $newCollectionName)
                            Button("Create") {
                                if !newCollectionName.isEmpty {
                                    libraryManager.createCollection(name: newCollectionName)
                                    if let newCollection = libraryManager.collections.first(where: { $0.name == newCollectionName }) {
                                        libraryManager.addBookmarkToCollection(bookmark: bookmark, collectionId: newCollection.id)
                                    }
                                    dismiss()
                                }
                            }
                            .disabled(newCollectionName.isEmpty)
                        }
                    }
                }
                
                Section {
                    ForEach(libraryManager.collections) { collection in
                        Button(action: {
                            libraryManager.addBookmarkToCollection(bookmark: bookmark, collectionId: collection.id)
                            dismiss()
                        }) {
                            HStack {
                                Image(systemName: "folder")
                                Text(collection.name)
                                Spacer()
                                Text("\(collection.bookmarks.count)")
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Add to Collection")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        isShowingNewCollectionField.toggle()
                    }) {
                        Image(systemName: "folder.badge.plus")
                    }
                }
            }
        }
    }
} 