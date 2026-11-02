// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "ConvCalcNative",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(name: "ConvCalcCore", targets: ["ConvCalcCore"]),
        .executable(name: "ConvCalcCoreCheck", targets: ["ConvCalcCoreCheck"])
    ],
    targets: [
        .target(
            name: "ConvCalcCore",
            path: "ios/ConvCalc/Core"
        ),
        .testTarget(
            name: "ConvCalcCoreTests",
            dependencies: ["ConvCalcCore"],
            path: "ios/ConvCalcTests"
        ),
        .executableTarget(
            name: "ConvCalcCoreCheck",
            dependencies: ["ConvCalcCore"],
            path: "ios/ConvCalcCoreCheck"
        )
    ]
)
