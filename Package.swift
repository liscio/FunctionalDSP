// swift-tools-version:5.0
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "FunctionalDSP",
    products: [
        // Products define the executables and libraries produced by a package, and make them visible to other packages.
        .library(
            name: "FunctionalDSP",
            targets: ["FunctionalDSP"]),
    ],
    dependencies: [
        // Dependencies declare other packages that this package depends on.
        .package(url: "https://github.com/MaddTheSane/SwiftMacTypes.git", from: "1.0.0"),
    ],
    targets: [
        // Targets are the basic building blocks of a package. A target can define a module or a test suite.
        // Targets can depend on other targets in this package, and on products in packages which this package depends on.
        .target(
            name: "FunctionalDSP",
            dependencies: [],
            path: "FunctionalDSP"),
        .testTarget(
            name: "FunctionalDSPTests",
            dependencies: ["FunctionalDSP"],
            path: "Tests/FunctionalDSPTests"),
    ]
)
