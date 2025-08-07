//
//  SettingsViewLibrary.swift
//  Sora
//
//  Created by paul on 05/02/25.
//

import SwiftUI
import UIKit

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
                Divider().padding(.horizontal, 16)
            }
        }
    }
}

fileprivate struct SettingsPickerRow<T: Hashable>: View {
    let icon: String
    let title: String
    let options: [T]
    let optionToString: (T) -> String
    @Binding var selection: T
    var showDivider: Bool = true
    
    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Image(systemName: icon)
                    .frame(width: 24, height: 24)
                    .foregroundStyle(.primary)
                
                Text(title)
                    .foregroundStyle(.primary)
                
                Spacer()
                
                Picker("", selection: $selection) {
                    ForEach(options, id: \.self) { option in
                        Text(optionToString(option)).tag(option)
                    }
                }
                .pickerStyle(MenuPickerStyle())
                .labelsHidden()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            
            if showDivider {
                Divider().padding(.horizontal, 16)
            }
        }
    }
}

struct SettingsViewLibrary: View {
    @AppStorage("mediaColumnsPortrait") private var mediaColumnsPortrait: Int = 2
    @AppStorage("mediaColumnsLandscape") private var mediaColumnsLandscape: Int = 4
    @AppStorage("librarySectionsOrderData") private var librarySectionsOrderData: Data = {
        try! JSONEncoder().encode(["continueWatching", "continueReading", "collections"])
    }()
    @AppStorage("disabledLibrarySectionsData") private var disabledLibrarySectionsData: Data = {
        try! JSONEncoder().encode([String]())
    }()
    
    private var librarySectionsOrder: [String] {
        get { (try? JSONDecoder().decode([String].self, from: librarySectionsOrderData)) ?? ["continueWatching", "continueReading", "collections"] }
        set { librarySectionsOrderData = try! JSONEncoder().encode(newValue) }
    }

    private var disabledLibrarySections: [String] {
        get { (try? JSONDecoder().decode([String].self, from: disabledLibrarySectionsData)) ?? [] }
        set { disabledLibrarySectionsData = try! JSONEncoder().encode(newValue) }
    }
    
    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 24) {
                SettingsSection(
                    title: NSLocalizedString("Media Grid Layout", comment: ""),
                    footer: NSLocalizedString("Adjust the number of media items per row in portrait and landscape modes.", comment: "")
                ) {
                    SettingsPickerRow(
                        icon: "rectangle.portrait",
                        title: NSLocalizedString("Portrait Columns", comment: ""),
                        options: UIDevice.current.userInterfaceIdiom == .pad ? Array(1...5) : Array(1...4),
                        optionToString: { "\($0)" },
                        selection: $mediaColumnsPortrait
                    )
                    
                    SettingsPickerRow(
                        icon: "rectangle",
                        title: NSLocalizedString("Landscape Columns", comment: ""),
                        options: UIDevice.current.userInterfaceIdiom == .pad ? Array(2...8) : Array(2...5),
                        optionToString: { "\($0)" },
                        selection: $mediaColumnsLandscape,
                        showDivider: false
                    )
                }
                
                SettingsSection(
                    title: NSLocalizedString("Library View", comment: ""),
                    footer: NSLocalizedString("Customize the sections shown in your library. You can reorder sections or disable them completely.", comment: "")
                ) {
                    VStack(spacing: 0) {
                        HStack {
                            Image(systemName: "arrow.up.arrow.down")
                                .frame(width: 24, height: 24)
                                .foregroundStyle(.primary)
                            
                            Text(NSLocalizedString("Library Sections Order", comment: ""))
                                .foregroundStyle(.primary)
                            
                            Spacer()
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        
                        List {
                            ForEach(Array(librarySectionsOrder.enumerated()), id: \.element) { index, section in
                                HStack {
                                    Text("\(index + 1)")
                                        .frame(width: 24, height: 24)
                                        .foregroundStyle(.gray)
                                    
                                    Image(systemName: sectionIcon(for: section))
                                        .frame(width: 24, height: 24)
                                    
                                    Text(sectionName(for: section))
                                        .foregroundStyle(.primary)
                                    
                                    Spacer()
                                    
                                    Toggle("", isOn: toggleBinding(for: section))
                                    .labelsHidden()
                                    .tint(.accentColor.opacity(0.7))
                                }
                                .padding(.horizontal, 16)
                                .padding(.vertical, 12)
                                .listRowBackground(Color.clear)
                                .listRowSeparator(.visible)
                                .listRowSeparatorTint(.gray.opacity(0.3))
                                .listRowInsets(EdgeInsets())
                            }
                            .onMove { from, to in
                                var arr = librarySectionsOrder
                                arr.move(fromOffsets: from, toOffset: to)
                                librarySectionsOrderData = try! JSONEncoder().encode(arr)
                            }
                        }
                        .listStyle(.plain)
                        .frame(height: CGFloat(librarySectionsOrder.count * 70))
                        .environment(\.editMode, .constant(.active))
                    }
                }
            }
            .padding(.vertical, 20)
        }
        .navigationTitle(NSLocalizedString("Library", comment: ""))
        .scrollViewBottomPadding()
    }
    
    private func sectionName(for section: String) -> String {
        switch section {
        case "continueWatching":
            return NSLocalizedString("Continue Watching", comment: "")
        case "continueReading":
            return NSLocalizedString("Continue Reading", comment: "")
        case "collections":
            return NSLocalizedString("Collections", comment: "")
        default:
            return section.capitalized
        }
    }
    
    private func sectionIcon(for section: String) -> String {
        switch section {
        case "continueWatching":
            return "play.circle"
        case "continueReading":
            return "book"
        case "collections":
            return "folder"
        default:
            return "questionmark.circle"
        }
    }
    
    private func toggleBinding(for section: String) -> Binding<Bool> {
        return Binding(
            get: { !self.disabledLibrarySections.contains(section) },
            set: { isEnabled in
                var sections = self.disabledLibrarySections
                if isEnabled {
                    sections.removeAll { $0 == section }
                } else {
                    if !sections.contains(section) {
                        sections.append(section)
                    }
                }
                self.disabledLibrarySectionsData = try! JSONEncoder().encode(sections)
            }
        )
    }
} 