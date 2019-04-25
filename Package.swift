// swift-tools-version:5.0
// The swift-tools-version declares the minimum version of Swift required to build this package.


import PackageDescription

let package = Package(
    name: "FunctionalDSP",
    products: [
        .library(
            name: "FunctionalDSP",
            targets: ["FunctionalDSP"]),
    ],
    dependencies: [
    ],
    targets: [
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
