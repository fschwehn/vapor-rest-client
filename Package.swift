// swift-tools-version:5.1
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "rest-client",
    platforms: [
        .macOS(.v10_14)
    ],
    products: [
        .library(
            name: "RestClient",
            targets: ["RestClient"]),
    ],
    dependencies: [
        // 💧 A server-side Swift web framework.
        .package(url: "https://github.com/vapor/vapor.git", from: "4.0.0-beta"),
    ],
    targets: [
        .target(
            name: "RestClient",
            dependencies: ["Vapor"]),
        .testTarget(
            name: "RestClientTests",
            dependencies: ["RestClient"]),
    ]
)
