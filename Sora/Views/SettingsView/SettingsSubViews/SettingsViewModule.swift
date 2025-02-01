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
    @State private var isRefreshing = false
    @State private var showingAddSheet = false
    @State private var moduleUrls = ""
    
    var body: some View {
        VStack {
            Form {
                if moduleManager.modules.isEmpty {
                    VStack(spacing: 8) {
                        Image(systemName: "plus.app")
                            .font(.largeTitle)
                            .foregroundColor(.secondary)
                        Text("No Modules")
                            .font(.headline)
                        Text("Click the plus button to add a module!")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .frame(maxWidth: .infinity)
                    }
                    .padding()
                    .frame(maxWidth: .infinity)
                } else {
                    ForEach(moduleManager.modules) { module in
                        ModuleRow(module: module, selectedModuleId: $selectedModuleId, moduleManager: moduleManager)
                    }
                }
            }
            .navigationTitle("Modules")
            .navigationBarItems(trailing: Button(action: {
                showingAddSheet = true
            }) {
                Image(systemName: "plus")
                    .resizable()
                    .padding(5)
            })
            .refreshable {
                isRefreshing = true
                await moduleManager.refreshModules()
                isRefreshing = false
            }
        }
        .sheet(isPresented: $showingAddSheet) {
            NavigationView {
                ModuleManagementSheet(moduleUrls: $moduleUrls, isPresented: $showingAddSheet, moduleManager: moduleManager)
            }
        }
        .alert(isPresented: .constant(errorMessage != nil)) {
            Alert(
                title: Text("Error"),
                message: Text(errorMessage ?? "Unknown error"),
                dismissButton: .default(Text("OK")) {
                    errorMessage = nil
                }
            )
        }
    }
}

struct ModuleRow: View {
    let module: ScrapingModule
    @Binding var selectedModuleId: String?
    @ObservedObject var moduleManager: ModuleManager
    
    var body: some View {
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
                UIPasteboard.general.string = module.metadataUrl
                DropManager.shared.showDrop(title: "Copied to Clipboard", subtitle: "", duration: 1.0, icon: UIImage(systemName: "doc.on.clipboard.fill"))
            }) {
                Label("Copy URL", systemImage: "doc.on.doc")
            }
            Button(role: .destructive) {
                if selectedModuleId != module.id.uuidString {
                    moduleManager.deleteModule(module)
                    DropManager.shared.showDrop(title: "Module Removed", subtitle: "", duration: 1.0, icon: UIImage(systemName: "trash"))
                }
            } label: {
                Label("Delete", systemImage: "trash")
            }
            .disabled(selectedModuleId == module.id.uuidString)
        }
        .swipeActions {
            if selectedModuleId != module.id.uuidString {
                Button(role: .destructive) {
                    moduleManager.deleteModule(module)
                    DropManager.shared.showDrop(title: "Module Removed", subtitle: "", duration: 1.0, icon: UIImage(systemName: "trash"))
                } label: {
                    Label("Delete", systemImage: "trash")
                }
            }
        }
    }
}

struct ModuleManagementSheet: View {
    @Binding var moduleUrls: String
    @Binding var isPresented: Bool
    @ObservedObject var moduleManager: ModuleManager
    @State private var isLoading = false
    @State private var errorMessage: String?
    
    var body: some View {
        Form {
            Section(header: Text("Add Module(s) URL")) {
                TextField("Enter URLs separated by commas", text: $moduleUrls)
                    .font(.body)
            }
            
            Section {
                Button(action: {
                    if let clipboardContent = UIPasteboard.general.string {
                        moduleUrls = clipboardContent
                        importModules()
                    }
                }) {
                    HStack {
                        Text("Import Modules from Clipboard")
                        Spacer()
                        if isLoading {
                            ProgressView()
                        }
                    }
                }
                .disabled(isLoading)
                
                Button(action: {
                    exportModules()
                }) {
                    Text("Export Modules to Clipboard")
                }
            }
        }
        .navigationTitle("Add Source")
        .navigationBarItems(
            leading: Button("Dismiss") {
                moduleUrls = ""
                isPresented = false
            },
            trailing: Button("Add") {
                importModules()
            }
            .disabled(moduleUrls.isEmpty || isLoading)
        )
        .alert(isPresented: .constant(errorMessage != nil)) {
            Alert(
                title: Text("Error"),
                message: Text(errorMessage ?? "Unknown error"),
                dismissButton: .default(Text("OK")) {
                    errorMessage = nil
                }
            )
        }
    }
    
    private func importModules() {
        isLoading = true
        errorMessage = nil
        let urls = moduleUrls.components(separatedBy: ",").map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
        
        Task {
            var addedCount = 0
            var duplicateCount = 0
            var failedCount = 0
            
            for url in urls {
                do {
                    _ = try await moduleManager.addModule(metadataUrl: url)
                    addedCount += 1
                } catch let error as NSError {
                    if error.domain == "Module already exists" {
                        duplicateCount += 1
                    } else {
                        failedCount += 1
                    }
                }
            }
            
            DispatchQueue.main.async {
                isLoading = false
                if addedCount > 0 {
                    DropManager.shared.showDrop(
                        title: "Added \(addedCount) module(s)",
                        subtitle: duplicateCount > 0 ? "\(duplicateCount) duplicate(s)" : "",
                        duration: 2.0,
                        icon: UIImage(systemName: "app.badge.checkmark")
                    )
                    moduleUrls = ""
                    isPresented = false
                } else {
                    if duplicateCount > 0 {
                        errorMessage = "All modules already exist"
                    } else {
                        errorMessage = "Failed to add any modules"
                    }
                }
            }
        }
    }
    
    private func exportModules() {
        let urls = moduleManager.modules.map { $0.metadataUrl }.joined(separator: ",")
        UIPasteboard.general.string = urls
        DropManager.shared.showDrop(
            title: "Modules Exported",
            subtitle: "\(moduleManager.modules.count) URLs copied to clipboard",
            duration: 2.0,
            icon: UIImage(systemName: "doc.on.clipboard.fill")
        )
    }
}
