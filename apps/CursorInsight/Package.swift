// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "CursorInsight",
    platforms: [.macOS(.v26)],
    targets: [
        .executableTarget(
            name: "CursorInsight",
            path: "CursorInsight",
            resources: [.copy("Resources")]
        ),
        .testTarget(
            name: "CursorInsightTests",
            dependencies: ["CursorInsight"],
            path: "CursorInsightTests"
        ),
    ]
)
