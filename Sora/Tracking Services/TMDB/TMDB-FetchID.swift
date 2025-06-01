//
//  TMDB-FetchID.swift
//  Sulfur
//
//  Created by Francesco on 01/06/25.
//

import Foundation

class TMDBFetcher {
    enum MediaType: String, CaseIterable {
        case tv, movie
    }
    
    struct TMDBResult: Decodable {
        let id: Int
        let name: String?
        let title: String?
        let popularity: Double
    }
    
    struct TMDBResponse: Decodable {
        let results: [TMDBResult]
    }
    
    private let apiKey = "738b4edd0a156cc126dc4a4b8aea4aca"
    private let session = URLSession.custom
    
    func fetchBestMatchID(for title: String, completion: @escaping (Int?, MediaType?) -> Void) {
        let group = DispatchGroup()
        var bestResults: [(id: Int, score: Double, type: MediaType)] = []
        
        for type in MediaType.allCases {
            group.enter()
            fetchBestMatchID(for: title, type: type) { id, score in
                if let id = id, let score = score {
                    bestResults.append((id, score, type))
                }
                group.leave()
            }
        }
        
        group.notify(queue: .main) {
            let best = bestResults.max { $0.score < $1.score }
            completion(best?.id, best?.type)
        }
    }
    
    private func fetchBestMatchID(for title: String, type: MediaType, completion: @escaping (Int?, Double?) -> Void) {
        let query = title.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        let urlString = "https://api.themoviedb.org/3/search/\(type.rawValue)?api_key=\(apiKey)&query=\(query)"
        guard let url = URL(string: urlString) else {
            completion(nil, nil)
            return
        }
        
        session.dataTask(with: url) { data, _, error in
            guard let data = data, error == nil else {
                completion(nil, nil)
                return
            }
            do {
                let response = try JSONDecoder().decode(TMDBResponse.self, from: data)
                let scored = response.results.map { result -> (Int, Double) in
                    let candidateTitle = type == .tv ? result.name ?? "" : result.title ?? ""
                    let similarity = TMDBFetcher.titleSimilarity(title, candidateTitle)
                    let score = (similarity * 0.7) + ((result.popularity / 100.0) * 0.3)
                    return (result.id, score)
                }
                let best = scored.max { $0.1 < $1.1 }
                completion(best?.0, best?.1)
            } catch {
                completion(nil, nil)
            }
        }.resume()
    }
    
    static func titleSimilarity(_ a: String, _ b: String) -> Double {
        let lowerA = a.lowercased()
        let lowerB = b.lowercased()
        let distance = Double(levenshtein(lowerA, lowerB))
        let maxLen = Double(max(lowerA.count, lowerB.count))
        if maxLen == 0 { return 1.0 }
        return 1.0 - (distance / maxLen)
    }
    
    static func levenshtein(_ a: String, _ b: String) -> Int {
        let a = Array(a)
        let b = Array(b)
        var dist = Array(repeating: Array(repeating: 0, count: b.count + 1), count: a.count + 1)
        for i in 0...a.count { dist[i][0] = i }
        for j in 0...b.count { dist[0][j] = j }
        for i in 1...a.count {
            for j in 1...b.count {
                if a[i-1] == b[j-1] {
                    dist[i][j] = dist[i-1][j-1]
                } else {
                    dist[i][j] = min(dist[i-1][j-1], dist[i][j-1], dist[i-1][j]) + 1
                }
            }
        }
        return dist[a.count][b.count]
    }
}
