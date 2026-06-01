// swift-tools-version: 6.1

import PackageDescription

let package = Package(
    name: "OpenRouterMonitor",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "OpenRouterMonitor", targets: ["OpenRouterMonitor"]),
        .executable(name: "OpenRouterMonitorCoreChecks", targets: ["OpenRouterMonitorCoreChecks"]),
        .library(name: "OpenRouterMonitorCore", targets: ["OpenRouterMonitorCore"])
    ],
    targets: [
        .target(
            name: "OpenRouterMonitorCore"
        ),
        .executableTarget(
            name: "OpenRouterMonitor",
            dependencies: ["OpenRouterMonitorCore"],
            resources: [
                .process("Resources")
            ]
        ),
        .executableTarget(
            name: "OpenRouterMonitorCoreChecks",
            dependencies: ["OpenRouterMonitorCore"]
        )
    ]
)
