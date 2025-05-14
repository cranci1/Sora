//
//  PerformanceMonitor.swift
//  Sora
//
//  Created by AI Assistant on 18/12/24.
//

import Foundation
import SwiftUI
import Kingfisher

/// Performance metrics tracking system
class PerformanceMonitor: ObservableObject {
    static let shared = PerformanceMonitor()
    
    // Published properties to allow UI observation
    @Published private(set) var networkRequestCount: Int = 0
    @Published private(set) var cacheHitCount: Int = 0
    @Published private(set) var cacheMissCount: Int = 0
    @Published private(set) var averageLoadTime: TimeInterval = 0
    @Published private(set) var memoryUsage: UInt64 = 0
    @Published private(set) var diskUsage: UInt64 = 0
    @Published private(set) var isEnabled: Bool = false
    
    // Internal tracking properties
    private var loadTimes: [TimeInterval] = []
    private var startTimes: [String: Date] = [:]
    private var memoryTimer: Timer?
    private var logTimer: Timer?
    
    private init() {
        // Default is off unless explicitly enabled
        isEnabled = UserDefaults.standard.bool(forKey: "enablePerformanceMonitoring")
        
        // Setup memory monitoring if enabled
        if isEnabled {
            startMonitoring()
        }
    }
    
    // MARK: - Public Methods
    
    /// Enable or disable the performance monitoring
    func setEnabled(_ enabled: Bool) {
        isEnabled = enabled
        UserDefaults.standard.set(enabled, forKey: "enablePerformanceMonitoring")
        
        if enabled {
            startMonitoring()
        } else {
            stopMonitoring()
        }
    }
    
    /// Reset all tracked metrics
    func resetMetrics() {
        networkRequestCount = 0
        cacheHitCount = 0
        cacheMissCount = 0
        averageLoadTime = 0
        loadTimes = []
        startTimes = [:]
        
        updateMemoryUsage()
        
        Logger.shared.log("Performance metrics reset", type: "Debug")
    }
    
    /// Track a network request starting
    func trackRequestStart(identifier: String) {
        guard isEnabled else { return }
        
        networkRequestCount += 1
        startTimes[identifier] = Date()
    }
    
    /// Track a network request completing
    func trackRequestEnd(identifier: String) {
        guard isEnabled, let startTime = startTimes[identifier] else { return }
        
        let endTime = Date()
        let duration = endTime.timeIntervalSince(startTime)
        loadTimes.append(duration)
        
        // Update average load time
        if !loadTimes.isEmpty {
            averageLoadTime = loadTimes.reduce(0, +) / Double(loadTimes.count)
        }
        
        // Remove start time to avoid memory leaks
        startTimes.removeValue(forKey: identifier)
    }
    
    /// Track a cache hit
    func trackCacheHit() {
        guard isEnabled else { return }
        cacheHitCount += 1
    }
    
    /// Track a cache miss
    func trackCacheMiss() {
        guard isEnabled else { return }
        cacheMissCount += 1
    }
    
    /// Get the current cache hit rate
    var cacheHitRate: Double {
        let total = cacheHitCount + cacheMissCount
        guard total > 0 else { return 0 }
        return Double(cacheHitCount) / Double(total)
    }
    
    /// Log current performance metrics
    func logMetrics() {
        guard isEnabled else { return }
        
        updateMemoryUsage()
        
        let hitRate = String(format: "%.1f%%", cacheHitRate * 100)
        let avgLoad = String(format: "%.2f", averageLoadTime)
        let memory = String(format: "%.1f MB", Double(memoryUsage) / (1024 * 1024))
        let disk = String(format: "%.1f MB", Double(diskUsage) / (1024 * 1024))
        
        let metrics = """
        Performance Metrics:
        - Network Requests: \(networkRequestCount)
        - Cache Hit Rate: \(hitRate) (\(cacheHitCount)/\(cacheHitCount + cacheMissCount))
        - Average Load Time: \(avgLoad)s
        - Memory Usage: \(memory)
        - Disk Usage: \(disk)
        """
        
        Logger.shared.log(metrics, type: "Performance")
    }
    
    // MARK: - Private Methods
    
    private func startMonitoring() {
        // Setup timer to update memory usage periodically
        memoryTimer = Timer.scheduledTimer(withTimeInterval: 10, repeats: true) { [weak self] _ in
            self?.updateMemoryUsage()
        }
        
        // Setup timer to log metrics periodically
        logTimer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in
            self?.logMetrics()
        }
        
        // Make sure timers run even when scrolling
        RunLoop.current.add(memoryTimer!, forMode: .common)
        RunLoop.current.add(logTimer!, forMode: .common)
        
        Logger.shared.log("Performance monitoring started", type: "Debug")
    }
    
    private func stopMonitoring() {
        memoryTimer?.invalidate()
        memoryTimer = nil
        
        logTimer?.invalidate()
        logTimer = nil
        
        Logger.shared.log("Performance monitoring stopped", type: "Debug")
    }
    
    private func updateMemoryUsage() {
        memoryUsage = getAppMemoryUsage()
        diskUsage = getCacheDiskUsage()
    }
    
    private func getAppMemoryUsage() -> UInt64 {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size) / 4
        
        let kerr: kern_return_t = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                task_info(mach_task_self_, task_flavor_t(MACH_TASK_BASIC_INFO), $0, &count)
            }
        }
        
        if kerr == KERN_SUCCESS {
            return info.resident_size
        } else {
            return 0
        }
    }
    
    private func getCacheDiskUsage() -> UInt64 {
        // Try to get Kingfisher's disk cache size
        let diskCache = ImageCache.default.diskStorage
        
        do {
            let size = try diskCache.totalSize()
            return UInt64(size)
        } catch {
            Logger.shared.log("Failed to get disk cache size: \(error)", type: "Error")
            return 0
        }
    }
}

// MARK: - Extensions to integrate with managers

extension EpisodeMetadataManager {
    /// Integrate performance tracking
    func trackFetchStart(anilistId: Int, episodeNumber: Int) {
        let identifier = "metadata_\(anilistId)_\(episodeNumber)"
        PerformanceMonitor.shared.trackRequestStart(identifier: identifier)
    }
    
    func trackFetchEnd(anilistId: Int, episodeNumber: Int) {
        let identifier = "metadata_\(anilistId)_\(episodeNumber)"
        PerformanceMonitor.shared.trackRequestEnd(identifier: identifier)
    }
    
    func trackCacheHit() {
        PerformanceMonitor.shared.trackCacheHit()
    }
    
    func trackCacheMiss() {
        PerformanceMonitor.shared.trackCacheMiss()
    }
}

extension ImagePrefetchManager {
    /// Integrate performance tracking
    func trackImageLoadStart(url: String) {
        let identifier = "image_\(url.hashValue)"
        PerformanceMonitor.shared.trackRequestStart(identifier: identifier)
    }
    
    func trackImageLoadEnd(url: String) {
        let identifier = "image_\(url.hashValue)"
        PerformanceMonitor.shared.trackRequestEnd(identifier: identifier)
    }
    
    func trackImageCacheHit() {
        PerformanceMonitor.shared.trackCacheHit()
    }
    
    func trackImageCacheMiss() {
        PerformanceMonitor.shared.trackCacheMiss()
    }
}

// MARK: - Debug View
struct PerformanceMetricsView: View {
    @ObservedObject private var monitor = PerformanceMonitor.shared
    @State private var isExpanded = false
    
    var body: some View {
        VStack {
            HStack {
                Text("Performance Metrics")
                    .font(.headline)
                
                Spacer()
                
                Button(action: {
                    isExpanded.toggle()
                }) {
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                }
            }
            .padding(.horizontal)
            
            if isExpanded {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Network Requests: \(monitor.networkRequestCount)")
                    Text("Cache Hit Rate: \(Int(monitor.cacheHitRate * 100))%")
                    Text("Avg Load Time: \(String(format: "%.2f", monitor.averageLoadTime))s")
                    Text("Memory: \(String(format: "%.1f MB", Double(monitor.memoryUsage) / (1024 * 1024)))")
                    
                    HStack {
                        Button(action: {
                            monitor.resetMetrics()
                        }) {
                            Text("Reset")
                                .font(.caption)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color.blue)
                                .foregroundColor(.white)
                                .cornerRadius(4)
                        }
                        
                        Button(action: {
                            monitor.logMetrics()
                        }) {
                            Text("Log")
                                .font(.caption)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color.green)
                                .foregroundColor(.white)
                                .cornerRadius(4)
                        }
                        
                        Toggle("", isOn: Binding(
                            get: { monitor.isEnabled },
                            set: { monitor.setEnabled($0) }
                        ))
                        .labelsHidden()
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal)
                .padding(.bottom, 8)
                .background(Color.secondary.opacity(0.1))
                .cornerRadius(8)
                .padding(.horizontal)
            }
        }
        .padding(.vertical, 4)
        .background(Color.secondary.opacity(0.05))
        .cornerRadius(8)
        .padding(8)
    }
} 