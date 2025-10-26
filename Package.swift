// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "swifthealth",
    platforms: [.macOS(.v13)],
    products: [
        // Products define the executables and libraries a package produces, making them visible to other packages.
        .executable(
            name: "swifthealth",
            targets: ["SwiftHealthCLI"]
        ),
    ],
    dependencies: [
        // Dependencies declare other packages that this package depends on.
        .package(url: "https://github.com/apple/swift-argument-parser", from: "1.3.0"),
        .package(url: "https://github.com/swiftlang/swift-syntax", from: "602.0.0"),
        .package(url: "https://github.com/tuist/XcodeProj", from: "9.5.0"),
    ],
    targets: [
        // Targets are the basic building blocks of a package, defining a module or a test suite.
        // Targets can depend on other targets in this package and products from dependencies.
        .target(
            name: "Core",
            dependencies: []
        ),
        .target(
            name: "Analyzers",
            dependencies: ["Core", "XcodeProj"]
        ),
        .executableTarget(
            name: "SwiftHealthCLI",
            dependencies: [
                "Core",
                "Analyzers",
                .product(name: "ArgumentParser", package: "swift-argument-parser"),
            ]
        ),
        .testTarget(
            name: "SwiftHealthTests",
            dependencies: ["SwiftHealthCLI"]
        ),
    ]
)
