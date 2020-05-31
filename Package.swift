// swift-tools-version:5.2
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "vapor-rest-client",
    platforms: [
        .macOS(.v10_15)
    ],
    products: [
        .library(
            name: "RestClient",
            targets: ["RestClient"]),
    ],
    dependencies: [
        // 💧 A server-side Swift web framework.
        .package(url: "https://github.com/vapor/vapor.git", from: "4.0.0-rc"),
    ],
    targets: [
        .target(name: "RestClient",dependencies: [
            .product(name: "Vapor", package: "vapor"),
        ]),
        .testTarget(name: "RestClientTests", dependencies: [
            "RestClient",
            .product(name: "XCTVapor", package: "vapor"),
        ]),
    ]
)
