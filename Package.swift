// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "DungeonGrid",
    platforms: [.macOS(.v12), .iOS(.v15), .tvOS(.v15), .watchOS(.v8)],
    products: [
        .library(name: "DungeonGrid", targets: ["DungeonGrid"])
    ],
    targets: [
        .target(name: "DungeonGrid"),
        .testTarget(
            name: "DungeonGridTests",
            dependencies: ["DungeonGrid"]
        )
    ]
)
