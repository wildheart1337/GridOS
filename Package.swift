// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "GridOS",
    defaultLocalization: "en",
    platforms: [
        .macOS("26.0")
    ],
    targets: [
        .executableTarget(
            name: "GridOS",
            dependencies: ["MultitouchKit", "ApplicationMonitorKit", "DesktopStateKit"],
            path: "Sources/GridOS",
            resources: [.process("Resources")]
        ),
        .executableTarget(
            name: "AppChangeProbe",
            dependencies: ["ApplicationMonitorKit"],
            path: "Sources/AppChangeProbe"
        ),
        .executableTarget(
            name: "GestureProbe",
            path: "Sources/GestureProbe"
        ),
        .executableTarget(
            name: "MultitouchProbe",
            dependencies: ["MultitouchKit"],
            path: "Sources/MultitouchProbe"
        ),
        .target(
            name: "MultitouchKit",
            path: "Sources/MultitouchKit"
        ),
        .target(
            name: "ApplicationMonitorKit",
            path: "Sources/ApplicationMonitorKit"
        ),
        .target(
            name: "DesktopStateKit",
            path: "Sources/DesktopStateKit"
        ),
        .testTarget(
            name: "MultitouchKitTests",
            dependencies: ["MultitouchKit"]
        ),
        .testTarget(
            name: "ApplicationMonitorKitTests",
            dependencies: ["ApplicationMonitorKit"]
        ),
        .testTarget(
            name: "DesktopStateKitTests",
            dependencies: ["DesktopStateKit"]
        ),
        .testTarget(
            name: "GridOSTests",
            dependencies: ["GridOS"]
        )
    ],
    swiftLanguageModes: [.v6]
)
