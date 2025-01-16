//
//  SettingsViewModule.swift
//  Sora
//
//  Created by Francesco on 05/01/25.
//

import SwiftUI
import Kingfisher

struct SettingsViewModule: View {
    @AppStorage("selectedModuleId") private var selectedModuleId: String?
    @EnvironmentObject var moduleManager: ModuleManager
    
    @State private var errorMessage: String?
    @State private var isLoading = false
    
    var body: some View {
        VStack {
            Form {
                ForEach(moduleManager.modules) { module in
                    HStack {
                        KFImage(URL(string: module.metadata.iconUrl))
                            .resizable()
                            .frame(width: 50, height: 50)
                            .clipShape(Circle())
                            .padding(.trailing, 10)
                        
                        VStack(alignment: .leading) {
                            HStack(alignment: .bottom, spacing: 4) {
                                Text(module.metadata.sourceName)
                                    .font(.headline)
                                    .foregroundColor(.primary)
                                Text("v\(module.metadata.version)")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }
                            Text("Author: \(module.metadata.author)")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            Text("Language: \(module.metadata.language)")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                        
                        if module.id.uuidString == selectedModuleId {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.accentColor)
                                .frame(width: 25, height: 25)
                        }
                    }
                    .contentShape(Rectangle())
                    .onTapGesture {
                        selectedModuleId = module.id.uuidString
                    }
                    .contextMenu {
                        Button(action: {
                            UIPasteboard.general.string = module.metadata.iconUrl
                        }) {
                            Label("Copy URL", systemImage: "doc.on.doc")
                        }
                        Button(role: .destructive) {
                            if selectedModuleId == module.id.uuidString {
                                selectedModuleId = nil
                            }
                            moduleManager.deleteModule(module)
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    }
                    .swipeActions {
                        Button(role: .destructive) {
                            if selectedModuleId == module.id.uuidString {
                                selectedModuleId = nil
                            }
                            moduleManager.deleteModule(module)
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    }
                }
            }
            .navigationTitle("Modules")
            .navigationBarItems(trailing: Button(action: {
                showAddModuleAlert()
            }) {
                Image(systemName: "plus")
                    .resizable()
                    .padding(5)
            })
        }
    }
    
    func showAddModuleAlert() {
        let alert = UIAlertController(title: "Add Module", message: "Enter the URL of the module file", preferredStyle: .alert)
        print("Attempting to add a module.")
        alert.addTextField { textField in
            textField.placeholder = "https://real.url/module.json"
        }
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: nil))
        alert.addAction(UIAlertAction(title: "Add", style: .default, handler: { _ in
            if let url = alert.textFields?.first?.text {
                addModule(from: url)
            }
        }))
        
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let rootViewController = windowScene.windows.first?.rootViewController {
            rootViewController.present(alert, animated: true, completion: nil)
        }
    }
    
    private func addModule(from url: String) {
        isLoading = true
        errorMessage = nil
        
        Task {
            do {
                _ = try await moduleManager.addModule(metadataUrl: url)
                DispatchQueue.main.async {
                    isLoading = false
                }
            } catch {
                DispatchQueue.main.async {
                    isLoading = false
                    errorMessage = error.localizedDescription
                }
            }
        }
    }
}
