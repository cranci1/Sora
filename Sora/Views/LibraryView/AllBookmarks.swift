//
//  AllBookmarks.swift
//  Sulfur
//
//  Created by paul on 29/04/2025.
//

import SwiftUI
import Kingfisher
import UIKit

extension View {
    func circularGradientOutlineTwo() -> some View {
        self.background(
            Circle()
                .stroke(
                    LinearGradient(
                        gradient: Gradient(stops: [
                            .init(color: Color.accentColor.opacity(0.25), location: 0),
                            .init(color: Color.accentColor.opacity(0), location: 1)
                        ]),
                        startPoint: .top,
                        endPoint: .bottom
                    ),
                    lineWidth: 0.5
                )
        )
    }
}

struct AllBookmarks: View {
    @EnvironmentObject var libraryManager: LibraryManager
    @EnvironmentObject var moduleManager: ModuleManager
    
    var body: some View {
        BookmarkGridView(
            bookmarks: libraryManager.bookmarks.sorted { $0.title < $1.title },
            moduleManager: moduleManager
        )
        .navigationBarBackButtonHidden(true)
        .navigationBarTitleDisplayMode(.inline)
        .onAppear(perform: setupNavigationController)
    }
    
    private func setupNavigationController() {
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let window = windowScene.windows.first,
           let navigationController = window.rootViewController?.children.first as? UINavigationController {
            navigationController.interactivePopGestureRecognizer?.isEnabled = true
            navigationController.interactivePopGestureRecognizer?.delegate = nil
        }
    }
}

struct BookmarkCell: View {
    let bookmark: LibraryItem
    @EnvironmentObject private var moduleManager: ModuleManager
    
    var body: some View {
        if let module = moduleManager.modules.first(where: { $0.id.uuidString == bookmark.moduleId }) {
            ZStack {
                KFImage(URL(string: bookmark.imageUrl))
                    .resizable()
                    .aspectRatio(0.72, contentMode: .fill)
                    .frame(width: 162, height: 243)
                    .cornerRadius(12)
                    .clipped()
                    .overlay(
                        ZStack {
                            Circle()
                                .fill(Color.black.opacity(0.5))
                                .frame(width: 28, height: 28)
                                .overlay(
                                    KFImage(URL(string: module.metadata.iconUrl))
                                        .resizable()
                                        .scaledToFill()
                                        .frame(width: 32, height: 32)
                                        .clipShape(Circle())
                                )
                        }
                        .padding(8),
                        alignment: .topLeading
                    )
                
                VStack {
                    Spacer()
                    Text(bookmark.title)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .lineLimit(2)
                        .foregroundColor(.white)
                        .padding(12)
                        .background(
                            LinearGradient(
                                colors: [
                                    .black.opacity(0.7),
                                    .black.opacity(0.0)
                                ],
                                startPoint: .bottom,
                                endPoint: .top
                            )
                            .shadow(color: .black, radius: 4, x: 0, y: 2)
                        )
                }
                .frame(width: 162)
            }
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .padding(4)
        }
    }
}

private extension View {
    func withNavigationBarModifiers() -> some View {
        self
            .navigationBarBackButtonHidden(true)
            .navigationBarTitleDisplayMode(.inline)
    }
    
    func withGridPadding() -> some View {
        self
            .padding(.top)
            .padding()
            .scrollViewBottomPadding()
    }
}
