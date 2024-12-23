//
//  SearchResultsView.swift
//  Sora
//
//  Created by Francesco on 18/12/24.
//

import SwiftUI
import Kingfisher
import SwiftSoup

struct SearchResultsView: View {
    let module: ModuleStruct?
    let searchText: String
    @State private var searchResults: [SearchResult] = []
    @State private var isLoading: Bool = true
    @State private var filter: FilterType = .all
    @AppStorage("listSearch") private var isListSearchEnabled: Bool = false
    
    enum FilterType: String, CaseIterable {
        case all = "All"
        case dub = "Dub"
        case sub = "Sub"
        case ova = "OVA"
        case ona = "ONA"
        case movie = "Movie"
    }
    
    var body: some View {
        if isListSearchEnabled {
            oldUI
        } else {
            modernUI
        }
    }
    
    var modernUI: some View {
        VStack {
            if isLoading {
                ProgressView()
                    .padding()
            } else if searchResults.isEmpty {
                Text("No results found")
                    .foregroundColor(.secondary)
                    .padding()
            } else {
                ScrollView {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 150))], spacing: 20) {
                        ForEach(filteredResults) { result in
                            NavigationLink(destination: AnimeInfoView(module: module!, anime: result)) {
                                VStack {
                                    KFImage(URL(string: result.imageUrl))
                                        .resizable()
                                        .aspectRatio(2/3, contentMode: .fill)
                                        .cornerRadius(10)
                                        .frame(width: 150, height: 225)
                                    
                                    Text(result.name)
                                        .font(.subheadline)
                                        .foregroundColor(Color.primary)
                                        .padding([.leading, .bottom], 8)
                                        .lineLimit(1)
                                }
                            }
                        }
                    }
                    .padding()
                }
                .navigationTitle("Results")
                .toolbar {
                    filterMenu
                }
            }
        }
        .onAppear {
            performSearch()
        }
    }
    
    var oldUI: some View {
        VStack {
            if isLoading {
                ProgressView()
                    .padding()
            } else if searchResults.isEmpty {
                Text("No results found")
                    .foregroundColor(.secondary)
                    .padding()
            } else {
                List {
                    ForEach(filteredResults) { result in
                        NavigationLink(destination: AnimeInfoView(module: module!, anime: result)) {
                            HStack {
                                KFImage(URL(string: result.imageUrl))
                                    .resizable()
                                    .scaledToFill()
                                    .frame(width: 100, height: 150)
                                    .clipped()
                                
                                VStack(alignment: .leading) {
                                    Text(result.name)
                                        .font(.system(size: 16))
                                        .padding(.leading, 10)
                                }
                            }
                            .padding(.vertical, 5)
                        }
                    }
                }
                .navigationTitle("Results")
                .toolbar {
                    filterMenu
                }
            }
        }
        .onAppear {
            performSearch()
        }
    }
    
    var filterMenu: some View {
        Menu {
            ForEach([FilterType.all], id: \.self) { filter in
                Button(action: {
                    self.filter = filter
                    performSearch()
                }) {
                    Label(filter.rawValue, systemImage: self.filter == filter ? "checkmark" : "")
                }
            }
            Menu("Audio") {
                ForEach([FilterType.dub, FilterType.sub], id: \.self) { filter in
                    Button(action: {
                        self.filter = filter
                        performSearch()
                    }) {
                        Label(filter.rawValue, systemImage: self.filter == filter ? "checkmark" : "")
                    }
                }
            }
            Menu("Format") {
                ForEach([FilterType.ova, FilterType.ona, FilterType.movie], id: \.self) { filter in
                    Button(action: {
                        self.filter = filter
                        performSearch()
                    }) {
                        Label(filter.rawValue, systemImage: self.filter == filter ? "checkmark" : "")
                    }
                }
            }
        } label: {
            Label("Filter", systemImage: filter == .all ? "line.horizontal.3.decrease.circle" : "line.horizontal.3.decrease.circle.fill")
        }
    }
    
    var filteredResults: [SearchResult] {
        switch filter {
        case .all:
            return searchResults
        case .dub:
            return searchResults.filter { $0.name.contains("Dub") || $0.name.contains("ITA") }
        case .sub:
            return searchResults.filter { !$0.name.contains("Dub") && !$0.name.contains("ITA") }
        case .ova, .ona:
            return searchResults.filter { $0.name.contains(filter.rawValue) }
        case .movie:
            return searchResults.filter { $0.name.contains("Movie") || $0.name.contains("Film") }
        }
    }
    
    func performSearch() {
        guard let module = module, !searchText.isEmpty else { return }
        
        let encodedSearchText = searchText.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? searchText
        let urlString = "\(module.module[0].search.url)?\(module.module[0].search.parameter)=\(encodedSearchText)"
        guard let url = URL(string: urlString) else { return }
        
        URLSession.custom.dataTask(with: url) { data, response, error in
            defer { isLoading = false }
            guard let data = data, error == nil else { return }
            
            do {
                let html = String(data: data, encoding: .utf8) ?? ""
                let document = try SwiftSoup.parse(html)
                let elements = try document.select(module.module[0].search.documentSelector)
                
                var results: [SearchResult] = []
                for element in elements {
                    let title = try element.select(module.module[0].search.title).text()
                    let href = try element.select(module.module[0].search.href).attr("href")
                    var imageURL = try element.select(module.module[0].search.image.url).attr(module.module[0].search.image.attribute)
                    
                    if !imageURL.starts(with: "http") {
                        imageURL = "\(module.module[0].details.baseURL)\(imageURL)"
                    }
                    
                    let result = SearchResult(name: title, imageUrl: imageURL, href: href)
                    results.append(result)
                }
                
                DispatchQueue.main.async {
                    self.searchResults = results
                }
            } catch {
                print("Error parsing HTML: \(error)")
                Logger.shared.log("Error parsing HTML: \(error)")
            }
        }.resume()
    }
}
