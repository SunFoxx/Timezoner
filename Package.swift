// swift-tools-version: 5.10

import PackageDescription

let package = Package(
    name: "Timezoner",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .library(name: "TimezonerCore", targets: ["TimezonerCore"]),
        .executable(name: "Timezoner", targets: ["Timezoner"])
    ],
    targets: [
        .target(
            name: "TimezonerCore",
            path: "Sources/TimezonerCore"
        ),
        .executableTarget(
            name: "Timezoner",
            dependencies: ["TimezonerCore"],
            path: "Sources/Timezoner"
        ),
        .testTarget(
            name: "TimezonerCoreTests",
            dependencies: ["TimezonerCore"],
            path: "Tests/TimezonerCoreTests"
        ),
        .testTarget(
            name: "TimezonerViewTests",
            dependencies: ["Timezoner", "TimezonerCore"],
            path: "Tests/TimezonerViewTests"
        )
    ],
    swiftLanguageVersions: [.v5]
)
