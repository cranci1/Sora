//
//  PerformanceMonitor.swift
//  Sora
//
//  Created by doomsboygaming on 5/22/25
//

import Foundation
import SwiftUI
import Kingfisher
import QuartzCore

/// Performance metrics tracking system with advanced jitter detection
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
    
    // Advanced performance metrics for jitter detection
    @Published private(set) var currentFPS: Double = 60.0
    @Published private(set) var mainThreadBlocks: Int = 0
    @Published private(set) var memorySpikes: Int = 0
    @Published private(set) var cpuUsage: Double = 0.0
    @Published private(set) var jitterEvents: Int = 0
    
    // Internal tracking properties
    private var loadTimes: [TimeInterval] = []
    private var startTimes: [String: Date] = [:]
    private var memoryTimer: Timer?
    private var logTimer: Timer?
    
    // Advanced monitoring properties
    private var displayLink: CADisplayLink?
    private var frameCount: Int = 0
    private var lastFrameTime: CFTimeInterval = 0
    private var frameTimes: [CFTimeInterval] = []
    private var lastMemoryUsage: UInt64 = 0
    private var mainThreadOperations: [String: CFTimeInterval] = [:]
    private var cpuTimer: Timer?
    
    // Thresholds for performance issues
    private let mainThreadBlockingThreshold: TimeInterval = 0.016 // 16ms for 60fps
    private let memorySpikeTreshold: UInt64 = 50 * 1024 * 1024 // 50MB spike
    private let fpsThreshold: Double = 50.0 // Below 50fps is considered poor
    
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
        
        // Reset advanced metrics
        mainThreadBlocks = 0
        memorySpikes = 0
        jitterEvents = 0
        frameTimes = []
        frameCount = 0
        mainThreadOperations = [:]
        
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
    
    // MARK: - Advanced Performance Monitoring
    
    /// Track the start of a main thread operation
    func trackMainThreadOperationStart(operation: String) {
        guard isEnabled else { return }
        mainThreadOperations[operation] = CACurrentMediaTime()
    }
    
    /// Track the end of a main thread operation and detect blocking
    func trackMainThreadOperationEnd(operation: String) {
        guard isEnabled, let startTime = mainThreadOperations[operation] else { return }
        
        let endTime = CACurrentMediaTime()
        let duration = endTime - startTime
        
        if duration > mainThreadBlockingThreshold {
            mainThreadBlocks += 1
            jitterEvents += 1
            
            let durationMs = Int(duration * 1000)
            Logger.shared.log("🚨 Main thread blocked for \(durationMs)ms during: \(operation)", type: "Performance")
        }
        
        mainThreadOperations.removeValue(forKey: operation)
    }
    
    /// Track memory spikes during downloads
    func checkMemorySpike() {
        guard isEnabled else { return }
        
        let currentMemory = getAppMemoryUsage()
        
        if lastMemoryUsage > 0 {
            let spike = currentMemory > lastMemoryUsage ? currentMemory - lastMemoryUsage : 0
            
            if spike > memorySpikeTreshold {
                memorySpikes += 1
                jitterEvents += 1
                
                let spikeSize = Double(spike) / (1024 * 1024)
                Logger.shared.log("🚨 Memory spike detected: +\(String(format: "%.1f", spikeSize))MB", type: "Performance")
            }
        }
        
        lastMemoryUsage = currentMemory
        memoryUsage = currentMemory
    }
    
    /// Start frame rate monitoring
    private func startFrameRateMonitoring() {
        guard displayLink == nil else { return }
        
        displayLink = CADisplayLink(target: self, selector: #selector(frameCallback))
        displayLink?.add(to: .main, forMode: .common)
        
        frameCount = 0
        lastFrameTime = CACurrentMediaTime()
        frameTimes = []
    }
    
    /// Stop frame rate monitoring
    private func stopFrameRateMonitoring() {
        displayLink?.invalidate()
        displayLink = nil
    }
    
    /// Frame callback for FPS monitoring
    @objc private func frameCallback() {
        let currentTime = CACurrentMediaTime()
        
        if lastFrameTime > 0 {
            let frameDuration = currentTime - lastFrameTime
            frameTimes.append(frameDuration)
            
            // Keep only last 60 frames for rolling average
            if frameTimes.count > 60 {
                frameTimes.removeFirst()
            }
            
            // Calculate current FPS
            if !frameTimes.isEmpty {
                let averageFrameTime = frameTimes.reduce(0, +) / Double(frameTimes.count)
                currentFPS = 1.0 / averageFrameTime
                
                // Detect FPS drops
                if currentFPS < fpsThreshold {
                    jitterEvents += 1
                    Logger.shared.log("🚨 FPS drop detected: \(String(format: "%.1f", currentFPS))fps", type: "Performance")
                }
            }
        }
        
        lastFrameTime = currentTime
        frameCount += 1
    }
    
    /// Get current CPU usage
    private func getCPUUsage() -> Double {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size) / 4
        
        let kerr: kern_return_t = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                task_info(mach_task_self_, task_flavor_t(MACH_TASK_BASIC_INFO), $0, &count)
            }
        }
        
        if kerr == KERN_SUCCESS {
            // This is a simplified CPU usage calculation
            // For more accurate results, we'd need to track over time
            return Double(info.user_time.seconds + info.system_time.seconds)
        } else {
            return 0.0
        }
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
        
        checkMemorySpike()
        
        let hitRate = String(format: "%.1f%%", cacheHitRate * 100)
        let avgLoad = String(format: "%.2f", averageLoadTime)
        let memory = String(format: "%.1f MB", Double(memoryUsage) / (1024 * 1024))
        let disk = String(format: "%.1f MB", Double(diskUsage) / (1024 * 1024))
        let fps = String(format: "%.1f", currentFPS)
        let cpu = String(format: "%.1f%%", cpuUsage)
        
        let metrics = """
        📊 Performance Metrics Report:
        ═══════════════════════════════
        Network & Cache:
        - Network Requests: \(networkRequestCount)
        - Cache Hit Rate: \(hitRate) (\(cacheHitCount)/\(cacheHitCount + cacheMissCount))
        - Average Load Time: \(avgLoad)s
        
        System Resources:
        - Memory Usage: \(memory)
        - Disk Usage: \(disk)
        - CPU Usage: \(cpu)
        
        Performance Issues:
        - Current FPS: \(fps)
        - Main Thread Blocks: \(mainThreadBlocks)
        - Memory Spikes: \(memorySpikes)
        - Total Jitter Events: \(jitterEvents)
        ═══════════════════════════════
        """
        
        Logger.shared.log(metrics, type: "Performance")
        
        // Alert if performance is poor
        if jitterEvents > 0 {
            Logger.shared.log("⚠️ Performance issues detected! Check logs above for details.", type: "Warning")
        }
    }
    
    // MARK: - Private Methods
    
    private func startMonitoring() {
        // Setup timer to update memory usage periodically and check for spikes
        memoryTimer = Timer.scheduledTimer(withTimeInterval: 2, repeats: true) { [weak self] _ in
            self?.checkMemorySpike()
        }
        
        // Setup timer to log metrics periodically
        logTimer = Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { [weak self] _ in
            self?.logMetrics()
        }
        
        // Setup CPU monitoring timer
        cpuTimer = Timer.scheduledTimer(withTimeInterval: 5, repeats: true) { [weak self] _ in
            self?.cpuUsage = self?.getCPUUsage() ?? 0.0
        }
        
        // Make sure timers run even when scrolling
        RunLoop.current.add(memoryTimer!, forMode: .common)
        RunLoop.current.add(logTimer!, forMode: .common)
        RunLoop.current.add(cpuTimer!, forMode: .common)
        
        // Start frame rate monitoring
        startFrameRateMonitoring()
        
        Logger.shared.log("Advanced performance monitoring started - tracking FPS, main thread blocks, memory spikes", type: "Debug")
    }
    
    private func stopMonitoring() {
        memoryTimer?.invalidate()
        memoryTimer = nil
        
        logTimer?.invalidate()
        logTimer = nil
        
        cpuTimer?.invalidate()
        cpuTimer = nil
        
        stopFrameRateMonitoring()
        
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
                    
                    Divider()
                    
                    // Advanced metrics
                    Text("FPS: \(String(format: "%.1f", monitor.currentFPS))")
                        .foregroundColor(monitor.currentFPS < 50 ? .red : .primary)
                    Text("Main Thread Blocks: \(monitor.mainThreadBlocks)")
                        .foregroundColor(monitor.mainThreadBlocks > 0 ? .red : .primary)
                    Text("Memory Spikes: \(monitor.memorySpikes)")
                        .foregroundColor(monitor.memorySpikes > 0 ? .orange : .primary)
                    Text("Jitter Events: \(monitor.jitterEvents)")
                        .foregroundColor(monitor.jitterEvents > 0 ? .red : .primary)
                    
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