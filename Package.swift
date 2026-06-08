// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "StockTrackerCore",
    platforms: [
        .iOS(.v17),
        .macOS(.v14)
    ],
    products: [
        .library(
            name: "StockTrackerCore",
            targets: ["StockTrackerCore"]),
    ],
    dependencies: [],
    targets: [
        .target(
            name: "StockTrackerCore",
            dependencies: []),
        .testTarget(
            name: "StockTrackerCoreTests",
            dependencies: ["StockTrackerCore"]),
    ]
)
