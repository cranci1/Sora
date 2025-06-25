//
//  WebAuthenticationManager.swift
//  Sulfur
//
//  Created by Francesco on 11/06/25.
//

import AuthenticationServices

class WebAuthenticationManager {
    static let shared = WebAuthenticationManager()
    private var webAuthSession: ASWebAuthenticationSession?
    
    func authenticate(url: URL, callbackScheme: String, completion: @escaping (Result<URL, Error>) -> Void) {
        webAuthSession = ASWebAuthenticationSession(url: url, callbackURLScheme: callbackScheme) { callbackURL, error in
            if let error = error {
                completion(.failure(error))
                return
            }
            
            if let callbackURL = callbackURL {
                completion(.success(callbackURL))
            } else {
                completion(.failure(NSError(domain: "WebAuthenticationManager", code: -1, userInfo: [NSLocalizedDescriptionKey: "Authentication callback URL not received"])))
            }
        }
        
        webAuthSession?.presentationContextProvider = WebAuthenticationPresentationContext.shared
        webAuthSession?.prefersEphemeralWebBrowserSession = true
        webAuthSession?.start()
    }
}

class WebAuthenticationPresentationContext: NSObject, ASWebAuthenticationPresentationContextProviding {
    static let shared = WebAuthenticationPresentationContext()
    
    func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let window = windowScene.windows.first else {
            fatalError("No window found")
        }
        
        return window
    }
}
