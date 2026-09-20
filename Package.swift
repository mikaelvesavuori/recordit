// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "RecordIt",
    platforms: [
        .macOS(.v15)
    ],
    products: [
        .executable(name: "RecordIt", targets: ["RecordIt"]),
        .library(name: "RecordItCore", targets: ["RecordItCore"])
    ],
    targets: [
        .executableTarget(
            name: "RecordIt",
            dependencies: ["RecordItCore"]
        ),
        .target(
            name: "RecordItCore",
            dependencies: []
        ),
        .testTarget(
            name: "RecordItCoreTests",
            dependencies: ["RecordItCore"]
        )
    ]
)
