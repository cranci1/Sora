// swift-tools-version:5.5
import PackageDescription

let package = Package(
    name: "Sora",
    platforms: [
        .iOS(.v15),
        .macOS(.v12)
    ],
    products: [
        .library(
            name: "Sora",
            targets: ["Sora"])
    ],
    dependencies: [
        .package(url: "https://github.com/onevcat/Kingfisher.git", exact: "7.9.1"),
        .package(url: "https://github.com/scinfu/SwiftSoup.git", exact: "2.4.0"),
        .package(url: "https://github.com/danwilliams64/OpenCastSwift.git", branch: "master"),
        .package(url: "https://github.com/SwiftyJSON/SwiftyJSON", exact: "5.0.2")
    ],
    targets: [
        .target(
            name: "Sora",
            dependencies: [
                "Kingfisher",
                "SwiftSoup",
                .product(name: "OpenCastSwift iOS", package: "OpenCastSwift"),
                "SwiftyJSON"
            ],
            path: "Sora")
    ]
) 