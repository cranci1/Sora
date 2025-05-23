//
//  SettingsViewPerformance.swift
//  Sora
//
//  Created by Claude on 19/06/24.
//

import SwiftUI

struct SettingsViewPerformance: View {
    @ObservedObject private var performanceMonitor = PerformanceMonitor.shared
    @State private var showResetConfirmation = false
    
    var body: some View {
        Form {
            Section(header: Text("Performance Monitoring")) {
                Toggle("Enable Performance Monitoring", isOn: Binding(
                    get: { performanceMonitor.isEnabled },
                    set: { performanceMonitor.setEnabled($0) }
                ))
                
                Button(action: {
                    showResetConfirmation = true
                }) {
                    HStack {
                        Text("Reset Metrics")
                            .foregroundColor(.primary)
                        Spacer()
                        Image(systemName: "arrow.clockwise")
                    }
                }
                .disabled(!performanceMonitor.isEnabled)
                
                Button(action: {
                    performanceMonitor.logMetrics()
                    DropManager.shared.showDrop(title: "Metrics Logged", subtitle: "Check logs for details", duration: 1.0, icon: UIImage(systemName: "doc.text"))
                }) {
                    HStack {
                        Text("Log Current Metrics")
                            .foregroundColor(.primary)
                        Spacer()
                        Image(systemName: "doc.text")
                    }
                }
                .disabled(!performanceMonitor.isEnabled)
            }
            
            if performanceMonitor.isEnabled {
                Section(header: Text("About Performance Monitoring"), footer: Text("Performance monitoring helps track app resource usage and identify potential issues with network requests, cache efficiency, and memory management.")) {
                    Text("Performance monitoring helps track app resource usage and identify potential issues with network requests, cache efficiency, and memory management.")
                        .font(.footnote)
                        .foregroundColor(.secondary)
                }
            }
        }
        .navigationTitle("Performance")
        .alert(isPresented: $showResetConfirmation) {
            Alert(
                title: Text("Reset Performance Metrics"),
                message: Text("Are you sure you want to reset all performance metrics? This action cannot be undone."),
                primaryButton: .destructive(Text("Reset")) {
                    performanceMonitor.resetMetrics()
                    DropManager.shared.showDrop(title: "Metrics Reset", subtitle: "", duration: 1.0, icon: UIImage(systemName: "arrow.clockwise"))
                },
                secondaryButton: .cancel()
            )
        }
    }
}

struct MetricRow: View {
    let title: String
    let value: String
    
    var body: some View {
        HStack {
            Text(title)
                .font(.system(size: 15))
                .foregroundColor(.secondary)
            Spacer()
            Text(value)
                .font(.system(size: 15, weight: .medium))
                .foregroundColor(.primary)
        }
    }
}

struct SettingsViewPerformance_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            SettingsViewPerformance()
        }
    }
} 