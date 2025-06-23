//
//  ChapterCell.swift
//  Sora
//
//  Created by paul on 20/06/25.
//

import SwiftUI

struct ChapterCell: View {
    let chapterNumber: String
    let chapterTitle: String
    let isCurrentChapter: Bool
    
    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                HStack(alignment: .center, spacing: 6) {
                    Text("Chapter \(chapterNumber)")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(.primary)
                        .lineLimit(1)
                    
                    if isCurrentChapter {
                        Text("Current")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.blue)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(
                                RoundedRectangle(cornerRadius: 6)
                                    .fill(Color.blue.opacity(0.18))
                            )
                    }
                    Spacer(minLength: 0)
                }
                Text(chapterTitle)
                    .font(.system(size: 15))
                    .foregroundColor(.secondary)
                    .lineLimit(2)
            }
            Spacer()
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 14)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(UIColor.systemBackground))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color.accentColor.opacity(0.08))
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(
                    LinearGradient(
                        gradient: Gradient(stops: [
                            .init(color: Color.accentColor.opacity(0.35), location: 0),
                            .init(color: Color.accentColor.opacity(0), location: 1)
                        ]),
                        startPoint: .top,
                        endPoint: .bottom
                    ),
                    lineWidth: 1.2
                )
        )
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}

#Preview {
    ChapterCell(
        chapterNumber: "1",
        chapterTitle: "Chapter 1: The Beginning",
        isCurrentChapter: true
    )
} 