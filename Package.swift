// swift-tools-version: 5.9
import Foundation
import PackageDescription

/// Path to Setapp's bundled frameworks directory, used as an rpath so that
/// SetappInterface's @rpath dependencies (AgentHealthMetrics, etc.) resolve.
let setappFrameworks: String =
    "\(NSHomeDirectory())/Library/Application Support/Setapp/LaunchAgents/" +
    "Setapp.app/Contents/Frameworks"

/// Setapp CLI package definition.
let package: Package = .init(
    name: "SetappCLI",
    platforms: [.macOS(.v12)],
    products: [
        .executable(name: "setapp-cli", targets: ["SetappCLI"])
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-argument-parser", from: "1.5.0")
    ],
    targets: [
        .target(
            name: "CBridge",
            path: "Sources/CBridge",
            publicHeadersPath: "include",
            linkerSettings: [
                .linkedFramework("Foundation")
            ]
        ),
        .executableTarget(
            name: "SetappCLI",
            dependencies: [
                "CBridge",
                .product(name: "ArgumentParser", package: "swift-argument-parser")
            ],
            path: "Sources/SetappCLI",
            linkerSettings: [
                .unsafeFlags([
                    "-Xlinker", "-sectcreate",
                    "-Xlinker", "__TEXT",
                    "-Xlinker", "__info_plist",
                    "-Xlinker", "Info.plist",
                    "-Xlinker", "-rpath",
                    "-Xlinker", setappFrameworks
                ])
            ]
        ),
        .testTarget(
            name: "SetappCLITests",
            dependencies: ["SetappCLI"],
            path: "Tests/SetappCLITests"
        )
    ]
)
