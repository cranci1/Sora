//
//  SettingsModuleView.swift
//  Sora
//
//  Created by Francesco on 18/12/24.
//

import SwiftUI
import Kingfisher

struct ErrorMessage: Identifiable {
    var id: String { message }
    let message: String
}

struct SettingsModuleView: View {
    @StateObject private var modulesManager = ModulesManager()
    @State private var showingAddModuleAlert = false
    @State private var moduleURL = ""
    @State private var errorMessage: ErrorMessage?
    @State private var previusImageURLs: [String: String] = [:]
    @State private var isImporting = false
    @State private var successMessage: String?
    
    var body: some View {
        VStack {
            if modulesManager.isLoading {
                ProgressView("Loading Modules...")
            } else {
                List {
                    ForEach(modulesManager.modules, id: \.name) { module in
                        HStack {
                            if let url = URL(string: module.iconURL) {
                                if previusImageURLs[module.name] != module.iconURL {
                                    KFImage(url)
                                        .resizable()
                                        .frame(width: 50, height: 50)
                                        .clipShape(Circle())
                                        .padding(.trailing, 10)
                                        .onAppear {
                                            previusImageURLs[module.name] = module.iconURL
                                        }
                                } else {
                                    KFImage(url)
                                        .resizable()
                                        .frame(width: 50, height: 50)
                                        .clipShape(Circle())
                                        .padding(.trailing, 10)
                                }
                            }
                            VStack(alignment: .leading) {
                                Text(module.name)
                                    .font(.headline)
                                    .foregroundColor(.primary)
                                Text("Version: \(module.version)")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                Text("Author: \(module.author.name)")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                Text("Language: \(module.language)")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }
                            Spacer()
                            Text(module.stream)
                                .font(.caption)
                                .padding(5)
                                .background(Color.accentColor)
                                .foregroundColor(Color.primary)
                                .clipShape(Capsule())
                        }
                        .contextMenu {
                            Button(action: {
                                UIPasteboard.general.string = modulesManager.moduleURLs[module.name]
                            }) {
                                Label("Copy URL", systemImage: "doc.on.doc")
                            }
                            Button(role: .destructive, action: {
                                modulesManager.deleteModule(named: module.name)
                            }) {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                    }
                    .onDelete(perform: deleteModule)
                }
                .navigationBarTitle("Modules")
                .navigationBarItems(
                    trailing: HStack {
                        Button(action: {
                            // Export all module URLs to clipboard
                            let urls = modulesManager.modules.compactMap { modulesManager.moduleURLs[$0.name] }
                            UIPasteboard.general.string = urls.joined(separator: ", ")
                            successMessage = "Module URLs exported to clipboard"
                        }) {
                            Image(systemName: "square.and.arrow.up")
                        }
                        Button(action: {
                            showAddModuleAlert()
                        }) {
                            Image(systemName: "plus")
                        }
                    }
                )
                .fileImporter(
                    isPresented: $isImporting,
                    allowedContentTypes: [.json],
                    allowsMultipleSelection: false
                ) { result in
                    switch result {
                    case .success(let urls):
                        guard let url = urls.first,
                              let data = try? Data(contentsOf: url) else { return }
                        do {
                            try modulesManager.importModules(from: data)
                            successMessage = "Modules imported successfully"
                        } catch {
                            errorMessage = ErrorMessage(message: "Failed to import modules: \(error.localizedDescription)")
                        }
                    case .failure(let error):
                        errorMessage = ErrorMessage(message: "Failed to import file: \(error.localizedDescription)")
                    }
                }
                .refreshable {
                    modulesManager.refreshModules()
                }
            }
        }
        .onAppear {
            modulesManager.loadModules()
        }
        .alert(item: $errorMessage) { error in
            Alert(title: Text("Error"), message: Text(error.message), dismissButton: .default(Text("OK")))
        }
        .alert("Success", isPresented: .init(
            get: { successMessage != nil },
            set: { if !$0 { successMessage = nil } }
        )) {
            Button("OK", role: .cancel) { successMessage = nil }
        } message: {
            if let message = successMessage {
                Text(message)
            }
        }
    }
    
    func showAddModuleAlert() {
        let alert = UIAlertController(
            title: "Add Module(s)",
            message: "Enter the URL(s) of the module file(s), separated by commas",
            preferredStyle: .alert
        )
        
        alert.addTextField { textField in
            textField.placeholder = "https://url1.json, https://url2.json"
        }
        
        alert.addAction(UIAlertAction(title: "Import from Clipboard", style: .default) { _ in
            if let clipboardText = UIPasteboard.general.string {
                // Split clipboard text by commas and clean up whitespace
                let urls = clipboardText.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }
                let urlString = urls.joined(separator: ", ")
                
                modulesManager.addModules(from: urlString) { result in
                    switch result {
                    case .success(let count):
                        successMessage = "Successfully added \(count) module(s)"
                    case .failure(let error):
                        errorMessage = ErrorMessage(message: error.localizedDescription)
                    }
                }
            } else {
                errorMessage = ErrorMessage(message: "No URL found in clipboard")
            }
        })
        
        alert.addAction(UIAlertAction(title: "Add", style: .default) { _ in
            if let urls = alert.textFields?.first?.text {
                modulesManager.addModules(from: urls) { result in
                    switch result {
                    case .success(let count):
                        successMessage = "Successfully added \(count) module(s)"
                    case .failure(let error):
                        errorMessage = ErrorMessage(message: error.localizedDescription)
                    }
                }
            }
        })
        
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let rootViewController = windowScene.windows.first?.rootViewController {
            rootViewController.present(alert, animated: true)
        }
    }
    
    func deleteModule(at offsets: IndexSet) {
        offsets.forEach { index in
            let module = modulesManager.modules[index]
            modulesManager.deleteModule(named: module.name)
        }
    }
}
