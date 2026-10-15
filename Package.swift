// swift-tools-version: 5.9
import PackageDescription
let package = Package(
    name: "NumPatch",
    defaultLocalization: "en",
    platforms: [.macOS(.v13)],
    products: [.executable(name: "NumPatch", targets: ["NumPatch"])],
    targets: [
        .target(name: "TouchBridge", linkerSettings: [.linkedLibrary("dl")]),
        .executableTarget(name: "NumPatch", dependencies: ["TouchBridge"], resources: [.process("Resources")]),
        .testTarget(name: "NumPatchTests", dependencies: ["NumPatch"])
    ]
)
