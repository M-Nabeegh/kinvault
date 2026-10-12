// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "KinVault",
    platforms: [.macOS(.v26)],
    products: [
        .executable(name: "KinVault", targets: ["KinVault"]),
        .executable(name: "kinvault-cli", targets: ["kinvault-cli"]),
        .library(name: "KinVaultCore", targets: ["KinVaultCore"]),
    ],
    targets: [
        .target(
            name: "KinVaultCore",
            path: "Sources/KinVaultCore"
        ),
        .executableTarget(
            name: "KinVault",
            dependencies: ["KinVaultCore"],
            path: "Sources/KinVault",
            swiftSettings: [.defaultIsolation(MainActor.self)]
        ),
        .executableTarget(
            name: "kinvault-cli",
            dependencies: ["KinVaultCore"],
            path: "Sources/kinvault-cli"
        ),
        .testTarget(
            name: "KinVaultCoreTests",
            dependencies: ["KinVaultCore"],
            path: "Tests/KinVaultCoreTests"
        ),
        .testTarget(
            name: "KinVaultAppTests",
            dependencies: ["KinVault", "KinVaultCore"],
            path: "Tests/KinVaultAppTests",
            swiftSettings: [.defaultIsolation(MainActor.self)]
        ),
    ]
)
