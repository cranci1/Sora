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

fileprivate struct SettingsToggleRow: View {
    let icon: String
    let title: String
    @Binding var isOn: Bool
    var showDivider: Bool = true
    
    init(icon: String, title: String, isOn: Binding<Bool>, showDivider: Bool = true) {
        self.icon = icon
        self.title = title
        self._isOn = isOn
        self.showDivider = showDivider
    }
    
    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Image(systemName: icon)
                    .frame(width: 24, height: 24)
                    .foregroundStyle(.primary)
                
                Text(title)
                    .foregroundStyle(.primary)
                
                Spacer()
                
                Toggle("", isOn: $isOn)
                    .labelsHidden()
                    .tint(.accentColor.opacity(0.7))
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            
            if showDivider {
                Divider()
                    .padding(.horizontal, 16)
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
                LazyImage(url: URL(string: module.metadata.iconUrl)) { state in
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
                    DropManager.shared.showDrop(title: NSLocalizedString("Copied to Clipboard", comment: ""), subtitle: "", duration: 1.0, icon: UIImage(systemName: "doc.on.clipboard.fill"))
                }) {
                    Label(NSLocalizedString("Copy URL", comment: ""), systemImage: "doc.on.doc")
                }
                Button(role: .destructive) {
                    if selectedModuleId != module.id.uuidString {
                        onDelete()
                    }
                } label: {
                    Label(NSLocalizedString("Delete", comment: ""), systemImage: "trash")
                }
                .disabled(selectedModuleId == module.id.uuidString)
            }
            .swipeActions {
                if selectedModuleId != module.id.uuidString {
                    Button(role: .destructive) {
                        onDelete()
                    } label: {
                        Label(NSLocalizedString("Delete", comment: ""), systemImage: "trash")
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
    @AppStorage("refreshModulesOnLaunch") private var refreshModulesOnLaunch: Bool = true
    
    @State private var errorMessage: String?
    @State private var isLoading = false
    @State private var isRefreshing = false
    @State private var moduleUrl: String = ""
    @State private var refreshTask: Task<Void, Never>?
    @State private var showLibrary = false
    
    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 24) {
                if moduleManager.modules.isEmpty {
                    SettingsSection(title: NSLocalizedString("Modules", comment: "")) {
                        VStack(spacing: 16) {
                            Image(systemName: "plus.app")
                                .font(.largeTitle)
                                .foregroundColor(.secondary)
                            Text(NSLocalizedString("No Modules", comment: ""))
                                .font(.headline)

                            if didReceiveDefaultPageLink {
                                NavigationLink(destination: CommunityLibraryView()
                                                .environmentObject(moduleManager)) {
                                    Text(NSLocalizedString("Check out some community modules here!", comment: ""))
                                        .font(.caption)
                                        .foregroundColor(.accentColor)
                                        .frame(maxWidth: .infinity)
                                }
                                .buttonStyle(PlainButtonStyle())
                            } else {
                                Text(NSLocalizedString("Click the plus button to add a module!", comment: ""))
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                    .frame(maxWidth: .infinity)
                            }
                        }
                        .padding(.vertical, 24)
                        .frame(maxWidth: .infinity)
                    }
                } else {
                    SettingsSection(title: NSLocalizedString("Installed Modules", comment: "")) {
                        ForEach(moduleManager.modules) { module in
                            ModuleListItemView(
                                module: module,
                                selectedModuleId: selectedModuleId,
                                onDelete: {
                                    moduleManager.deleteModule(module)
                                    DropManager.shared.showDrop(title: NSLocalizedString("Module Removed", comment: ""), subtitle: "", duration: 1.0, icon: UIImage(systemName: "trash"))
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
                
                SettingsSection(
                    title: NSLocalizedString("Module Settings", comment: ""),
                    footer: NSLocalizedString("Note that the modules will be replaced only if there is a different version string inside the JSON file.", comment: "")
                ) {
                    SettingsToggleRow(
                        icon: "arrow.clockwise",
                        title: NSLocalizedString("Refresh Modules on Launch", comment: ""),
                        isOn: $refreshModulesOnLaunch,
                        showDivider: false
                    )
                }
            }
            .padding(.vertical, 20)
        }
        .scrollViewBottomPadding()
        .navigationTitle(NSLocalizedString("Modules", comment: ""))
        .navigationBarItems(trailing:
            HStack(spacing: 16) {
                if didReceiveDefaultPageLink {
                    Button(action: {
                        showLibrary = true
                    }) {
                        Image(systemName: "books.vertical.fill")
                            .resizable()
                            .frame(width: 20, height: 20)
                            .padding(5)
                    }
                    .accessibilityLabel(NSLocalizedString("Open Community Library", comment: ""))
                }

                Button(action: {
                    showAddModuleAlert()
                }) {
                    Image(systemName: "plus")
                        .resizable()
                        .frame(width: 20, height: 20)
                        .padding(5)
                }
                .accessibilityLabel(NSLocalizedString("Add Module", comment: ""))
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
