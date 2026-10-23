// swift-tools-version: 6.2

import PackageDescription

// Swift 6 language mode is the default for tools-version 6.x, so strict
// concurrency checking is on for every target. Unlike the app target, the
// packages do not default to MainActor isolation: domain code stays nonisolated.
let swiftSettings: [SwiftSetting] = [
    .enableUpcomingFeature("MemberImportVisibility"),
    .enableUpcomingFeature("NonisolatedNonsendingByDefault"),
]

let package = Package(
    name: "DietappKit",
    // macOS lets `swift test` run the package tests without a simulator.
    platforms: [.iOS(.v26), .macOS(.v26)],
    products: [
        .library(name: "NutritionKit", targets: ["NutritionKit"]),
        .library(name: "LoggingKit", targets: ["LoggingKit"]),
        .library(name: "FoodParsingKit", targets: ["FoodParsingKit"]),
        .library(name: "FoodVisionKit", targets: ["FoodVisionKit"]),
    ],
    targets: [
        .target(name: "NutritionKit", swiftSettings: swiftSettings),
        .target(name: "LoggingKit", dependencies: ["NutritionKit"], swiftSettings: swiftSettings),
        .target(name: "FoodParsingKit", swiftSettings: swiftSettings),
        .target(name: "FoodVisionKit", swiftSettings: swiftSettings),

        .testTarget(name: "NutritionKitTests", dependencies: ["NutritionKit"], swiftSettings: swiftSettings),
        .testTarget(name: "LoggingKitTests", dependencies: ["LoggingKit"], swiftSettings: swiftSettings),
        .testTarget(name: "FoodParsingKitTests", dependencies: ["FoodParsingKit"], swiftSettings: swiftSettings),
        .testTarget(name: "FoodVisionKitTests", dependencies: ["FoodVisionKit"], swiftSettings: swiftSettings),
    ]
)
