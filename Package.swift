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
        .executable(name: "golden-suggest", targets: ["golden-suggest"]),
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
        .executableTarget(
            name: "golden-suggest",
            dependencies: ["SentimentKit"]
        ),
    ]
)
