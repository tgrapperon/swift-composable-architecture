// swift-tools-version:5.3
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
  name: "Benchmarks",
  platforms: [
    .iOS(.v13),
    .macOS(.v10_15),
    .tvOS(.v13),
    .watchOS(.v6),
  ],
  products: [
    .library(
      name: "Benchmarks",
      targets: ["Benchmarks"]),
  ],
  dependencies: [
    .package(path: "../")
  ],
  targets: [
    .target(
      name: "Benchmarks",
      dependencies: [
        .product(name: "ComposableArchitecture", package: "swift-composable-architecture"),
      ]),
    .binaryTarget(name: "LocalTCA", path: "Internal/Frameworks/LocalTCA.xcframework"),
    .binaryTarget(name: "ReferenceTCA", path: "Internal/Frameworks/ReferenceTCA.xcframework"),
    .testTarget(
      name: "BenchmarksTests",
      dependencies: [
        "Benchmarks",
        "LocalTCA",
        "ReferenceTCA",
      ]),
  ])
