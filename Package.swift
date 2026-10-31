// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "MacTVLauncher",
    platforms: [.macOS(.v13)],
    products: [.executable(name: "TVLauncher", targets: ["TVLauncher"])],
    targets: [
        .target(name: "LauncherCore"),
        .executableTarget(name: "TVLauncher", dependencies: ["LauncherCore"]),
        .testTarget(name: "LauncherCoreTests", dependencies: ["LauncherCore"])
    ]
)
