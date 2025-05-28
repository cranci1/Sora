//
//  SearchViewComponents.swift
//  Sora
//
//  Created by Francesco on 27/01/25.
//

import SwiftUI
import Kingfisher

struct ModuleSelectorMenu: View {
    let selectedModule: ScrapingModule?
    let moduleGroups: [String]
    let modulesByLanguage: [String: [ScrapingModule]]
    let selectedModuleId: String?
    let onModuleSelected: (String) -> Void
    
    var body: some View {
        Menu {
            ForEach(moduleGroups, id: \.self) { language in
                Menu(language) {
                    ForEach(modulesByLanguage[language] ?? [], id: \.id) { module in
                        Button {
                            onModuleSelected(module.id.uuidString)
                        } label: {
                            HStack {
                                KFImage(URL(string: module.metadata.iconUrl))
                                    .resizable()
                                    .aspectRatio(contentMode: .fit)
                                    .frame(width: 20, height: 20)
                                    .cornerRadius(4)
                                Text(module.metadata.sourceName)
                                if module.id.uuidString == selectedModuleId {
                                    Image(systemName: "checkmark")
                                        .foregroundColor(.accentColor)
                                }
                            }
                        }
                    }
                }
            }
        } label: {
            if let selectedModule = selectedModule {
                KFImage(URL(string: selectedModule.metadata.iconUrl))
                    .resizable()
                    .frame(width: 36, height: 36)
                    .clipShape(Circle())
            } else {
                Image(systemName: "questionmark.app.fill")
                    .resizable()
                    .frame(width: 36, height: 36)
                    .clipShape(Circle())
                    .foregroundColor(.secondary)
            }
        }
    }
}

struct SearchContent: View {
    let selectedModule: ScrapingModule?
    let searchQuery: String
    let searchHistory: [String]
    let searchItems: [SearchItem]
    let isSearching: Bool
    let hasNoResults: Bool
    let columns: [GridItem]
    let columnsCount: Int
    let cellWidth: CGFloat
    let onHistoryItemSelected: (String) -> Void
    let onHistoryItemDeleted: (Int) -> Void
    let onClearHistory: () -> Void
    
    var body: some View {
        VStack(spacing: 0) {
            if selectedModule == nil {
                VStack(spacing: 8) {
                    Image(systemName: "questionmark.app")
                        .font(.largeTitle)
                        .foregroundColor(.secondary)
                    Text("No Module Selected")
                        .font(.headline)
                    Text("Please select a module from settings")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding()
                .frame(maxWidth: .infinity)
                .background(Color(.systemBackground))
                .shadow(color: Color.black.opacity(0.1), radius: 2, y: 1)
            }
            
            if searchQuery.isEmpty {
                if !searchHistory.isEmpty {
                    SearchHistorySection(title: "Recent Searches") {
                        VStack(spacing: 0) {
                            HStack {
                                Spacer()
                                Button(action: onClearHistory) {
                                    Text("Clear")
                                        .foregroundColor(.accentColor)
                                }
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 12)
                            
                            Divider()
                                .padding(.horizontal, 16)
                            
                            ForEach(searchHistory.indices, id: \.self) { index in
                                SearchHistoryRow(
                                    text: searchHistory[index],
                                    onTap: {
                                        onHistoryItemSelected(searchHistory[index])
                                    },
                                    onDelete: {
                                        onHistoryItemDeleted(index)
                                    },
                                    showDivider: index < searchHistory.count - 1
                                )
                            }
                        }
                    }
                    .padding(.vertical)
                }
            } else {
                if let module = selectedModule {
                    if !searchItems.isEmpty {
                        SearchResultsGrid(
                            items: searchItems,
                            columns: columns,
                            selectedModule: module
                        )
                    } else {
                        SearchStateView(
                            isSearching: isSearching,
                            hasNoResults: hasNoResults,
                            columnsCount: columnsCount,
                            cellWidth: cellWidth
                        )
                    }
                }
            }
        }
    }
} 
