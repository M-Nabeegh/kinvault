// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "KinVault",
    platforms: [.macOS(.v26)],
    products: [
        .executable(name: "KinVault", targets: ["KinVault"]),
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
        .testTarget(
            name: "KinVaultCoreTests",
            dependencies: ["KinVaultCore"],
            path: "Tests/KinVaultCoreTests"
        ),
    ]
)
