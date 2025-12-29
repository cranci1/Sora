//
//  IntroDB-FetchIntro.swift
//  Sora
//
//  Created by 686udjie on 29/12/25.
//

import Foundation

class IntroDBFetcher {
    struct IntroResponse: Decodable {
        let imdb_id: String
        let season: Int
        let episode: Int
        let start_sec: Double
        let end_sec: Double
        let start_ms: Int
        let end_ms: Int
        let confidence: Double
    }

    struct ErrorResponse: Decodable {
        let error: String
    }

    private let session = URLSession.custom

    func fetchIntro(imdbId: String, season: Int, episode: Int, completion: @escaping (IntroResponse?) -> Void) {
        let urlString = "https://api.introdb.app/intro?imdb_id=\(imdbId)&season=\(season)&episode=\(episode)"
        guard let url = URL(string: urlString) else {
            completion(nil)
            return
        }

        session.dataTask(with: url) { data, response, error in
            guard let data = data, error == nil else {
                completion(nil)
                return
            }

            let httpResponse = response as? HTTPURLResponse
            if httpResponse?.statusCode == 404 {
                // No intro data available
                completion(nil)
                return
            }

            do {
                let intro = try JSONDecoder().decode(IntroResponse.self, from: data)
                completion(intro)
            } catch {
                // Try to decode as error response
                if let errorResponse = try? JSONDecoder().decode(ErrorResponse.self, from: data) {
                    Logger.shared.log("IntroDB error: \(errorResponse.error)", type: "Debug")
                }
                completion(nil)
            }
        }.resume()
    }
}
