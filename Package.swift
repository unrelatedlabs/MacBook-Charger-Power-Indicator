// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "MacBat",
    platforms: [
        .macOS(.v13)
    ],
    targets: [
        .executableTarget(
            name: "MacBat",
            path: "Sources/MacBat"
        )
    ]
)
