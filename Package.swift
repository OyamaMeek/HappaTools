// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "HappaTools",
    platforms: [.macOS(.v11)],
    products: [
        .library(name: "HappaToolsShared", targets: ["HappaToolsShared"])
    ],
    targets: [
        .target(
            name: "HappaToolsShared",
            path: "Shared",
            linkerSettings: [.linkedLibrary("sqlite3")]
        ),
        .testTarget(
            name: "HappaToolsSharedTests",
            dependencies: ["HappaToolsShared"],
            path: "Tests/HappaToolsSharedTests"
        )
    ],
    swiftLanguageVersions: [.v5]
)
