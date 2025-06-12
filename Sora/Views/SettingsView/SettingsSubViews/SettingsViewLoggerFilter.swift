//
//  SettingsViewLoggerFilter.swift
//  Sora
//
//  Created by seiike on 21/01/2025.
//

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

struct LogFilter: Identifiable, Hashable {
    let id = UUID()
    let type: String
    var isEnabled: Bool
    let description: String
}

class LogFilterViewModel: ObservableObject {
    static let shared = LogFilterViewModel()
    
    @Published var filters: [LogFilter] = [] {
        didSet {
            saveFiltersToUserDefaults()
        }
    }
    
    private let userDefaultsKey = "LogFilterStates"
    private let hardcodedFilters: [(type: String, description: String, defaultState: Bool)] = [
        (NSLocalizedString("General", comment: ""), NSLocalizedString("General events and activities.", comment: ""), true),
        (NSLocalizedString("Stream", comment: ""), NSLocalizedString("Streaming and video playback.", comment: ""), true),
        (NSLocalizedString("Error", comment: ""), NSLocalizedString("Errors and critical issues.", comment: ""), true),
        (NSLocalizedString("Debug", comment: ""), NSLocalizedString("Debugging and troubleshooting.", comment: ""), false),
        (NSLocalizedString("Download", comment: ""), NSLocalizedString("HLS video downloading.", comment: ""), true),
        ("HTMLStrings", "", false)
    ]
    
    private init() {
        loadFilters()
    }
    
    func loadFilters() {
        if let savedStates = UserDefaults.standard.dictionary(forKey: userDefaultsKey) as? [String: Bool] {
            filters = hardcodedFilters.map {
                LogFilter(
                    type: $0.type,
                    isEnabled: savedStates[$0.type] ?? $0.defaultState,
                    description: $0.description
                )
            }
        } else {
            filters = hardcodedFilters.map {
                LogFilter(type: $0.type, isEnabled: $0.defaultState, description: $0.description)
            }
        }
    }
    
    func toggleFilter(for type: String) {
        if let index = filters.firstIndex(where: { $0.type == type }) {
            filters[index].isEnabled.toggle()
        }
    }
    
    func isFilterEnabled(for type: String) -> Bool {
        return filters.first(where: { $0.type == type })?.isEnabled ?? true
    }
    
    private func saveFiltersToUserDefaults() {
        let states = filters.reduce(into: [String: Bool]()) { result, filter in
            result[filter.type] = filter.isEnabled
        }
        UserDefaults.standard.set(states, forKey: userDefaultsKey)
    }
}

struct SettingsViewLoggerFilter: View {
    @ObservedObject var viewModel = LogFilterViewModel.shared
    
    private func iconForFilter(_ type: String) -> String {
        switch type {
        case "General": return "gear"
        case "Stream": return "play.circle"
        case "Error": return "exclamationmark.triangle"
        case "Debug": return "ladybug"
        case "Download": return "arrow.down.circle"
        case "HTMLStrings": return "text.alignleft"
        default: return "circle"
        }
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                SettingsSection(title: NSLocalizedString("Log Types", comment: "")) {
                    ForEach($viewModel.filters) { $filter in
                        SettingsToggleRow(
                            icon: iconForFilter(filter.type),
                            title: filter.type,
                            isOn: $filter.isEnabled,
                            showDivider: viewModel.filters.last?.id != filter.id
                        )
                    }
                }
            }
            .padding(.vertical, 20)
        }
        .navigationTitle(NSLocalizedString("Log Filters", comment: ""))
    }
}
