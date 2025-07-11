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
    var progress: Double = 0.0
    var href: String = ""
    
    private var progressText: String {
        if progress >= 0.98 {
            return "Completed"
        } else if progress > 0 {
            return "\(Int(progress * 100))%"
        } else {
            return "New"
        }
    }
    
    private var progressColor: Color {
        if progress >= 0.98 {
            return .green
        } else if progress > 0 {
            return .blue
        } else {
            return .secondary
        }
    }
    
    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                HStack(alignment: .center, spacing: 6) {
                    Text("Chapter \(chapterNumber)")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(.primary)
                        .lineLimit(1)
                    
                    if progress > 0 {
                        Text(progressText)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(progressColor)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(
                                RoundedRectangle(cornerRadius: 6)
                                    .fill(progressColor.opacity(0.18))
                            )
                    }
                    Spacer(minLength: 0)
                }
                Text(chapterTitle)
                    .font(.system(size: 15))
                    .foregroundColor(.secondary)
                    .lineLimit(2)
                
                if progress > 0 && progress < 0.98 {
                    ProgressView(value: progress)
                        .progressViewStyle(LinearProgressViewStyle())
                        .frame(height: 3)
                        .padding(.top, 4)
                }
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
    VStack(spacing: 16) {
        ChapterCell(
            chapterNumber: "1",
            chapterTitle: "Chapter 1: The Beginning",
            isCurrentChapter: false,
            progress: 0.0
        )
        
        ChapterCell(
            chapterNumber: "2",
            chapterTitle: "Chapter 2: The Journey",
            isCurrentChapter: false,
            progress: 0.45
        )
        
        ChapterCell(
            chapterNumber: "3",
            chapterTitle: "Chapter 3: The Conclusion",
            isCurrentChapter: false,
            progress: 1.0
        )
    }
    .padding()
} 