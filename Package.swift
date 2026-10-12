// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "Topmost",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(
            name: "Topmost",
            targets: ["Topmost"]
        ),
        .library(
            name: "TopmostCore",
            targets: ["TopmostCore"]
        )
    ],
    dependencies: [],
    targets: [
        .target(
            name: "TopmostCore",
            dependencies: [],
            path: "Sources/TopmostCore"
        ),
        .executableTarget(
            name: "Topmost",
            dependencies: ["TopmostCore"],
            path: "Sources/Topmost",
            exclude: ["Resources"]
        ),
        .executableTarget(
            name: "TopmostTests",
            dependencies: ["TopmostCore"],
            path: "Tests/TopmostTests"
        )
    ]
)
