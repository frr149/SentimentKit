// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "SentimentKit",
    platforms: [
        .macOS(.v14),
        .iOS(.v17),
    ],
    products: [
        .library(name: "SentimentKit", targets: ["SentimentKit"]),
    ],
    targets: [
        .target(
            name: "SentimentKit",
            resources: [
                .process("Resources"),
            ]
        ),
        .testTarget(
            name: "SentimentKitTests",
            dependencies: ["SentimentKit"]
        ),
    ]
)
