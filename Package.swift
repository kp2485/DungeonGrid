// swift-tools-version: 5.10
import PackageDescription

let package = Package(
    name: "DungeonGrid",
    platforms: [.macOS(.v12), .iOS(.v15), .tvOS(.v15), .watchOS(.v8)],
    products: [
        .library(name: "DungeonGrid", targets: ["DungeonGrid"])
    ],
    dependencies: [ ],
    targets: [
        .target(name: "DungeonGrid"),
        .testTarget(
            name: "DungeonGridTests",
            dependencies: ["DungeonGrid"]
        )
    ]
)
