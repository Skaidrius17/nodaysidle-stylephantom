// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "StylePhantom",
    platforms: [.macOS(.v15)],
    targets: [
        .executableTarget(
            name: "StylePhantom",
            path: "Sources/StylePhantom",
            resources: [
                .process("Metal/TimelineShaders.metal")
            ]
        ),
        .testTarget(
            name: "StylePhantomTests",
            dependencies: ["StylePhantom"],
            path: "Tests/StylePhantomTests"
        )
    ]
)
