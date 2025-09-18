// swift-tools-version: 5.10
import PackageDescription

let package = Package(
    name: "DungeonGrid",
    platforms: [.macOS(.v12), .iOS(.v15), .tvOS(.v15), .watchOS(.v8)],
    products: [
        .library(name: "DungeonGrid", targets: ["DungeonGrid"])
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-testing.git", from: "0.8.0")
    ],
    targets: [
        .target(name: "DungeonGrid"),
        .testTarget(
            name: "DungeonGridTests",
            dependencies: ["DungeonGrid", .product(name: "Testing", package: "swift-testing")]
        )
    ]
)
