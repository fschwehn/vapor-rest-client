// swift-tools-version:4.1
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "RestClient",
    products: [
        .library(
            name: "RestClient",
            targets: ["RestClient"]),
    ],
    dependencies: [
        // 💧 A server-side Swift web framework.
        .package(url: "https://github.com/vapor/vapor.git", from: "3.0.0"),
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
