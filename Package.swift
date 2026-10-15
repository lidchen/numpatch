// swift-tools-version: 5.9
import PackageDescription
let package = Package(
    name: "NumPatch",
    defaultLocalization: "en",
    platforms: [.macOS(.v13)],
    products: [.executable(name: "NumPatch", targets: ["NumPatch"])],
    targets: [
        .target(name: "TouchBridge", linkerSettings: [.linkedLibrary("dl")]),
        .executableTarget(
            name: "NumPatch",
            dependencies: ["TouchBridge"],
            resources: [
                .copy("Resources/en.lproj"),
                .copy("Resources/zh-Hans.lproj")
            ]
        ),
        .testTarget(name: "NumPatchTests", dependencies: ["NumPatch"])
    ]
)
