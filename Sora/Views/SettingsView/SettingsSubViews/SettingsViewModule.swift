//
//  SettingsViewModule.swift
//  Sora
//
//  Created by Francesco on 05/01/25.
//

import NukeUI
import SwiftUI

fileprivate struct SettingsSection<Content: View>: View {
    let title: String
    let footer: String?
    let content: Content
    
    init(title: String, footer: String? = nil, @ViewBuilder content: () -> Content) {
        self.title = title
        self.footer = footer
        self.content = content()
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title.uppercased())
                .font(.footnote)
                .foregroundStyle(.gray)
                .padding(.horizontal, 20)
            
            VStack(spacing: 0) {
                content
            }
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(
                        LinearGradient(
                            gradient: Gradient(stops: [
                                .init(color: Color.accentColor.opacity(0.3), location: 0),
                                .init(color: Color.accentColor.opacity(0), location: 1)
                            ]),
                            startPoint: .top,
                            endPoint: .bottom
                        ),
                        lineWidth: 0.5
                    )
            )
            .padding(.horizontal, 20)
            
            if let footer = footer {
                Text(footer)
                    .font(.footnote)
                    .foregroundStyle(.gray)
                    .padding(.horizontal, 20)
                    .padding(.top, 4)
            }
        }
    }
}

fileprivate struct ModuleListItemView: View {
    let module: Module
    let selectedModuleId: String?
    let onDelete: () -> Void
    let onSelect: () -> Void
    
    var body: some View {
        VStack(spacing: 0) {
            HStack {
                LazyImage(source: URL(string: module.metadata.iconUrl)) { state in
                    if let uiImage = state.imageContainer?.image {
                        Image(uiImage: uiImage)
                            .resizable()
                            .frame(width: 40, height: 40)
                            .clipShape(Circle())
                            .padding(.trailing, 10)
                    } else {
                        Circle()
                            .frame(width: 40, height: 40)
                            .padding(.trailing, 10)
                    }
                }
                
                VStack(alignment: .leading, spacing: 2) {
                    HStack(alignment: .bottom, spacing: 4) {
                        Text(module.metadata.sourceName)
                            .font(.headline)
                            .foregroundStyle(.primary)
                        Text("v\(module.metadata.version)")
                            .font(.caption)
                            .foregroundStyle(.gray)
                    }
                    
                    HStack(spacing: 8) {
                        Text(module.metadata.author.name)
                            .font(.caption)
                            .foregroundStyle(.gray)
                        
                        Text("•")
                            .font(.caption)
                            .foregroundStyle(.gray)
                        
                        Text(module.metadata.language)
                            .font(.caption)
                            .foregroundStyle(.gray)
                    }
                }
                
                Spacer()
                
                if module.id.uuidString == selectedModuleId {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(Color.accentColor)
                        .frame(width: 20, height: 20)
                }
            }
            .contentShape(Rectangle())
            .onTapGesture(perform: onSelect)
            .contextMenu {
                Button(action: {
                    UIPasteboard.general.string = module.metadataUrl
                    DropManager.shared.showDrop(title: "Copied to Clipboard", subtitle: "", duration: 1.0, icon: UIImage(systemName: "doc.on.clipboard.fill"))
                }) {
                    Label("Copy URL", systemImage: "doc.on.doc")
                }
                Button(role: .destructive) {
                    if selectedModuleId != module.id.uuidString {
                        onDelete()
                    }
                } label: {
                    Label("Delete", systemImage: "trash")
                }
                .disabled(selectedModuleId == module.id.uuidString)
            }
            .swipeActions {
                if selectedModuleId != module.id.uuidString {
                    Button(role: .destructive) {
                        onDelete()
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
    }
}

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
        ScrollView {
            VStack(spacing: 24) {
                if moduleManager.modules.isEmpty {
                    SettingsSection(title: "Modules") {
                        VStack(spacing: 16) {
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
                        .padding(.vertical, 24)
                        .frame(maxWidth: .infinity)
                    }
                } else {
                    SettingsSection(title: "Installed Modules") {
                        ForEach(moduleManager.modules) { module in
                            ModuleListItemView(
                                module: module,
                                selectedModuleId: selectedModuleId,
                                onDelete: {
                                    moduleManager.deleteModule(module)
                                    DropManager.shared.showDrop(title: "Module Removed", subtitle: "", duration: 1.0, icon: UIImage(systemName: "trash"))
                                },
                                onSelect: {
                                    selectedModuleId = module.id.uuidString
                                }
                            )
                            
                            if module.id != moduleManager.modules.last?.id {
                                Divider()
                                    .padding(.horizontal, 16)
                            }
                        }
                    }
                }
            }
            .padding(.vertical, 20)
        }
        .scrollViewBottomPadding()
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
            
            clipboardAlert.addAction(UIAlertAction(title: "Enter Manually", style: .default, handler: { _ in
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
