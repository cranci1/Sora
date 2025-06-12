//
//  URLSession.swift
//  Sora-JS
//
//  Created by Francesco on 05/01/25.
//

import Foundation
import Network

class FetchDelegate: NSObject, URLSessionTaskDelegate {
    private let allowRedirects: Bool
    
    init(allowRedirects: Bool) {
        self.allowRedirects = allowRedirects
    }
    deinit { Logger.shared.log("FetchDelegate deallocated", type: "Debug")
    }
    
    func urlSession(_ session: URLSession, task: URLSessionTask, willPerformHTTPRedirection response: HTTPURLResponse, newRequest request: URLRequest, completionHandler: @escaping (URLRequest?) -> Void) {
        if(allowRedirects) {
            completionHandler(request)
        } else {
            completionHandler(nil)
        }
    }
}

extension URLSession {
    static let userAgents = [
        "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/129.0.0.0 Safari/537.36",
        "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/128.0.0.0 Safari/537.36",
        "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/127.0.0.0 Safari/537.36",
        "Mozilla/5.0 (Windows NT 10.0; Win64; x64; rv:128.0) Gecko/20100101 Firefox/128.0",
        "Mozilla/5.0 (Windows NT 10.0; Win64; x64; rv:127.0) Gecko/20100101 Firefox/127.0",
        "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/129.0.0.0 Safari/537.36 Edg/129.0.2569.45",
        "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/128.0.0.0 Safari/537.36 Edg/128.0.2478.89",
        "Mozilla/5.0 (Macintosh; Intel Mac OS X 14_7_0) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/129.0.0.0 Safari/537.36",
        "Mozilla/5.0 (Macintosh; Intel Mac OS X 14_6_2) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/128.0.0.0 Safari/537.36",
        "Mozilla/5.0 (Macintosh; Intel Mac OS X 15_1_1) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/19.1 Safari/605.1.15",
        "Mozilla/5.0 (Macintosh; Intel Mac OS X 15_0_2) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/19.0 Safari/605.1.15",
        "Mozilla/5.0 (Macintosh; Intel Mac OS X 15.1; rv:128.0) Gecko/20100101 Firefox/128.0",
        "Mozilla/5.0 (Macintosh; Intel Mac OS X 15.0; rv:127.0) Gecko/20100101 Firefox/127.0",
        "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/129.0.0.0 Safari/537.36",
        "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/128.0.0.0 Safari/537.36",
        "Mozilla/5.0 (X11; Linux x86_64; rv:128.0) Gecko/20100101 Firefox/128.0",
        "Mozilla/5.0 (X11; Linux x86_64; rv:127.0) Gecko/20100101 Firefox/127.0",
        "Mozilla/5.0 (Linux; Android 15; SM-S928B) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/129.0.6782.112 Mobile Safari/537.36",
        "Mozilla/5.0 (Linux; Android 15; Pixel 9) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/129.0.6782.112 Mobile Safari/537.36",
        "Mozilla/5.0 (iPhone; CPU iPhone OS 18_3_1 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/19.3 Mobile/15E148 Safari/604.1",
        "Mozilla/5.0 (iPad; CPU OS 18_3_1 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/19.3 Mobile/15E148 Safari/604.1",
        "Mozilla/5.0 (Android 15; Mobile; rv:128.0) Gecko/128.0 Firefox/128.0",
        "Mozilla/5.0 (Android 15; Mobile; rv:127.0) Gecko/127.0 Firefox/127.0"
    ]
    
    static var randomUserAgent: String = {
        userAgents.randomElement() ?? userAgents[0]
    }()
    
    static let custom: URLSession = {
        let configuration = URLSessionConfiguration.default
        configuration.httpAdditionalHeaders = ["User-Agent": randomUserAgent]
        return URLSession(configuration: configuration)
    }()
    
    static func fetchData(allowRedirects:Bool) -> URLSession
    {
        let delegate = FetchDelegate(allowRedirects:allowRedirects)
        let configuration = URLSessionConfiguration.default
        configuration.httpAdditionalHeaders = ["User-Agent": randomUserAgent]
        return URLSession(configuration: configuration, delegate: delegate, delegateQueue: nil)
    }
}

enum NetworkType {
    case wifi
    case cellular
    case unknown
}

@available(iOS 14.0, *)
class NetworkMonitor: ObservableObject {
    static let shared = NetworkMonitor()
    
    private let monitor = NWPathMonitor()
    private let queue = DispatchQueue(label: "NetworkMonitor")
    
    @Published var currentNetworkType: NetworkType = .unknown
    @Published var isConnected: Bool = false
    
    private init() {
        startMonitoring()
    }
    
    private func startMonitoring() {
        monitor.pathUpdateHandler = { [weak self] path in
            DispatchQueue.main.async {
                self?.isConnected = path.status == .satisfied
                self?.currentNetworkType = self?.getNetworkType(from: path) ?? .unknown
            }
        }
        monitor.start(queue: queue)
    }
    
    private func getNetworkType(from path: NWPath) -> NetworkType {
        if path.usesInterfaceType(.wifi) {
            return .wifi
        } else if path.usesInterfaceType(.cellular) {
            return .cellular
        } else {
            return .unknown
        }
    }
    
    static func getCurrentNetworkType() -> NetworkType {
        if #available(iOS 14.0, *) {
            return shared.currentNetworkType
        } else {
            return .unknown
        }
    }
    
    deinit {
        monitor.cancel()
    }
}
