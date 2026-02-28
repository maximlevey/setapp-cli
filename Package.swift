// swift-tools-version: 5.9
import PackageDescription

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
                    "-Xlinker", "Info.plist"
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
