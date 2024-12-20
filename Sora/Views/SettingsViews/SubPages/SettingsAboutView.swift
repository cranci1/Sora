//
//  SettingsAboutView.swift
//  Sora
//
//  Created by Francesco on 18/12/24.
//

import SwiftUI
import Kingfisher

struct AboutView: View {
    var body: some View {
        Form {
            Section(footer: Text("Sora is a free open source app, under the GPLv3.0 License. You can find the entire Sora code in the github repo.")) {
                HStack(alignment: .center, spacing: 10) {
                    KFImage(URL(string: "https://raw.githubusercontent.com/cranci1/Sora/main/Sora/Assets.xcassets/AppIcon.appiconset/180.png"))
                        .resizable()
                        .frame(width: 80, height: 80)
                        .clipShape(Circle())
                    
                    VStack(alignment: .leading) {
                        Text("Sora")
                            .font(.largeTitle)
                            .fontWeight(.bold)
                        
                        Text("Version b1.0.0")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }
                .padding(.vertical)
            }
            
            Section(header: Text("Developer")) {
                Button(action: {
                    if let url = URL(string: "https://github.com/cranci1") {
                        UIApplication.shared.open(url)
                    }
                }) {
                    HStack {
                        KFImage(URL(string: "https://avatars.githubusercontent.com/u/100066266?v=4"))
                            .resizable()
                            .frame(width: 40, height: 40)
                            .clipShape(Circle())
                        
                        VStack(alignment: .leading) {
                            Text("cranci1")
                                .font(.headline)
                                .foregroundColor(.yellow)
                            Text("YAY it's me")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                        Image(systemName: "safari")
                            .foregroundColor(.yellow)
                    }
                }
            }
            
            Section(header: Text("Huge thanks"), footer: Text("A huge thanks to the Miru Development team for their support and contributions to Sora. I wont ever be able to thank them enough. Thanks a lot <3")) {
                HStack {
                    KFImage(URL(string: "https://storage.ko-fi.com/cdn/useruploads/e68c31f0-7e66-4d63-934a-0508ce443bc0_e71506-30ce-4a01-9ac3-892ffcd18b77.png"))
                        .resizable()
                        .frame(width: 40, height: 40)
                        .clipShape(Circle())
                    
                    Text("Miru Development Team")
                        .font(.headline)
                        .foregroundColor(.green)
                }
                Button(action: {
                    if let url = URL(string: "https://github.com/bshar1865") {
                        UIApplication.shared.open(url)
                    }
                }) {
                    HStack {
                        KFImage(URL(string: "https://avatars.githubusercontent.com/u/98615778?v=4"))
                            .resizable()
                            .frame(width: 40, height: 40)
                            .clipShape(Circle())
                        
                        VStack(alignment: .leading) {
                            Text("MA.")
                                .font(.headline)
                                .foregroundColor(.orange)
                            Text("Discord Helper")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                        Image(systemName: "safari")
                            .foregroundColor(.orange)
                    }
                }
                HStack {
                    KFImage(URL(string: "https://cdn.discordapp.com/avatars/1072985316916469870/6bc6c23a6f22f932d23f2c2452f755f7.png?size=4096"))
                        .resizable()
                        .frame(width: 40, height: 40)
                        .clipShape(Circle())
                    
                    VStack(alignment: .leading) {
                        Text("50/50")
                            .font(.headline)
                            .foregroundColor(.orange)
                        Text("Discord Helper & Designer")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }
            }
            
            Section(header: Text("Acknowledgements"), footer: Text("Thanks to the creators of this frameworks, that made Sora creation much simplier.")) {
                Button(action: {
                    if let url = URL(string: "https://github.com/scinfu/SwiftSoup") {
                        UIApplication.shared.open(url)
                    }
                }) {
                    HStack {
                        KFImage(URL(string: "https://raw.githubusercontent.com/scinfu/SwiftSoup/master/swiftsoup.png"))
                            .resizable()
                            .frame(width: 40, height: 40)
                        
                        VStack(alignment: .leading) {
                            Text("SwiftSoup")
                                .font(.headline)
                                .foregroundColor(.red)
                            Text("Web scraping")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                        Image(systemName: "safari")
                            .foregroundColor(.red)
                    }
                }
                Button(action: {
                    if let url = URL(string: "https://github.com/onevcat/Kingfisher") {
                        UIApplication.shared.open(url)
                    }
                }) {
                    HStack {
                        KFImage(URL(string: "https://products.fileformat.com/image/swift/kingfisher/header-image.png"))
                            .resizable()
                            .frame(width: 40, height: 40)
                        
                        VStack(alignment: .leading) {
                            Text("Kingfisher")
                                .font(.headline)
                                .foregroundColor(.blue)
                            Text("Images caching and loading")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                        Image(systemName: "safari")
                            .foregroundColor(.blue)
                    }
                }
            }
        }
        .navigationTitle("About")
    }
}
