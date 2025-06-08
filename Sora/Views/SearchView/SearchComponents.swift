//
//  SearchComponents.swift
//  Sora
//
//  Created by Francesco on 27/01/25.
//

import SwiftUI

struct SearchItem: Identifiable {
    let id = UUID()
    let title: String
    let imageUrl: String
    let href: String
}

struct SearchHistorySection<Content: View>: View {
    let title: String
    let content: Content
    init(title: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title.uppercased())
                .font(.footnote)
                .foregroundStyle(Color.secondary)
                .padding(.horizontal, 20)
            VStack(spacing: 0) {
                content
            }
        }
        .padding(.vertical, 16)
    }
}


struct SearchHistoryRow: View {
    let text: String
    let onTap: () -> Void
    let onDelete: () -> Void
    var showDivider: Bool = true
    
    var body: some View {
        HStack {
            Image(systemName: "clock")
                .frame(width: 24, height: 24)
                .foregroundStyle(Color.primary)
            
            Text(text)
                .foregroundStyle(Color.primary)
            
            Spacer()
            
            Button(action: onDelete) {
                Image(systemName: "xmark.circle.fill")
                    .foregroundStyle(Color.secondary)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .contentShape(Rectangle())
        .onTapGesture(perform: onTap)
        
        if showDivider {
            Divider()
                .padding(.horizontal, 16)
        }
    }
}
