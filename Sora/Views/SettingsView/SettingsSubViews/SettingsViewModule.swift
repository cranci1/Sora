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
    @AppStorage("didReceiveDefaultPageLink") private var didReceiveDefaultPageLink: Bool = false
    
    @State private var errorMessage: String?
    @State private var isLoading = false
    @State private var isRefreshing = false
    @State private var moduleUrl: String = ""
    @State private var refreshTask: Task<Void, Never>?
    @State private var showLibrary = false
    
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

                        if didReceiveDefaultPageLink {
                            NavigationLink(destination: CommunityLibraryView()
                                            .environmentObject(moduleManager)) {
                                Text("Check out some community modules here!")
                                    .font(.caption)
                                    .foregroundColor(.accentColor)
                                    .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(PlainButtonStyle())
                        } else {
                            Text("Click the plus button to add a module!")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .frame(maxWidth: .infinity)
                        }
                    }
                    .padding()
                    .frame(maxWidth: .infinity)
                } else {
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
                                Text("Author: \(module.metadata.author.name)")
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
            }
            .navigationTitle("Modules")
            .navigationBarItems(trailing:
                HStack(spacing: 16) {
                    if didReceiveDefaultPageLink && !moduleManager.modules.isEmpty {
                        Button(action: {
                            showLibrary = true
                        }) {
                            Image(systemName: "books.vertical.fill")
                                .resizable()
                                .frame(width: 20, height: 20)
                                .padding(5)
                        }
                        .accessibilityLabel("Open Community Library")
                    }

                    Button(action: {
                        showAddModuleAlert()
                    }) {
                        Image(systemName: "plus")
                            .resizable()
                            .frame(width: 20, height: 20)
                            .padding(5)
                    }
                    .accessibilityLabel("Add Module")
                }
            )
            .background(
                NavigationLink(
                    destination: CommunityLibraryView()
                        .environmentObject(moduleManager),
                    isActive: $showLibrary
                ) { EmptyView() }
            )
            .refreshable {
                isRefreshing = true
                refreshTask?.cancel()
                refreshTask = Task {
                    await moduleManager.refreshModules()
                    isRefreshing = false
                }
            }
        }
        .onAppear {
            refreshTask = Task {
                await moduleManager.refreshModules()
            }
        }
        .onDisappear {
            refreshTask?.cancel()
        }
        .alert("Error", isPresented: Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )) {
            Button("OK") {
                errorMessage = nil
            }
        } message: {
            Text(errorMessage ?? "Unknown error")
        }
    }
    
    func showAddModuleAlert() {
        let pasteboardString = UIPasteboard.general.string ?? ""

        if !pasteboardString.isEmpty {
            let clipboardAlert = UIAlertController(
                title: "Clipboard Detected",
                message: "We found some text in your clipboard. Would you like to use it as the module URL?",
                preferredStyle: .alert
            )
            
            clipboardAlert.addAction(UIAlertAction(title: "Use Clipboard", style: .default, handler: { _ in
                self.displayModuleView(url: pasteboardString)
            }))
            
            clipboardAlert.addAction(UIAlertAction(title: "Enter Manually", style: .cancel, handler: { _ in
                self.showManualUrlAlert()
            }))
            
            if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
               let rootViewController = windowScene.windows.first?.rootViewController {
                rootViewController.present(clipboardAlert, animated: true, completion: nil)
            }
            
        } else {
            showManualUrlAlert()
        }
    }

    func showManualUrlAlert() {
        let alert = UIAlertController(
            title: "Add Module",
            message: "Enter the URL of the module file",
            preferredStyle: .alert
        )
        
        alert.addTextField { textField in
            textField.placeholder = "https://real.url/module.json"
        }
        
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: nil))
        alert.addAction(UIAlertAction(title: "Add", style: .default, handler: { _ in
            if let url = alert.textFields?.first?.text, !url.isEmpty {
                self.displayModuleView(url: url)
            }
        }))
        
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let rootViewController = windowScene.windows.first?.rootViewController {
            rootViewController.present(alert, animated: true, completion: nil)
        }
    }

    func displayModuleView(url: String) {
        DispatchQueue.main.async {
            let addModuleView = ModuleAdditionSettingsView(moduleUrl: url)
                .environmentObject(self.moduleManager)
            let hostingController = UIHostingController(rootView: addModuleView)
            
            if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
               let window = windowScene.windows.first {
                window.rootViewController?.present(hostingController, animated: true, completion: nil)
            }
        }
    }

}
