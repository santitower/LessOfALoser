// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "PhoneLLMCore",
    platforms: [
        .iOS(.v17),
        .macOS(.v13)
    ],
    products: [
        .library(name: "WellnessCore", targets: ["WellnessCore"])
    ],
    targets: [
        .target(
            name: "WellnessCore",
            path: "Sources/WellnessCore"
        ),
        .testTarget(
            name: "WellnessCoreTests",
            dependencies: ["WellnessCore"],
            path: "Tests/WellnessCoreTests"
        )
    ]
)
