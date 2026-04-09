// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "Floart",
    platforms: [.macOS(.v26)],
    targets: [
        .executableTarget(
            name: "Floart",
            path: "Floart",
            resources: [.copy("Resources")]
        ),
        .testTarget(
            name: "FloartTests",
            dependencies: ["Floart"],
            path: "FloartTests"
        ),
    ]
)
