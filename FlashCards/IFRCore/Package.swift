// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "IFRCore",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [.library(name: "IFRCore", targets: ["IFRCore"])],
    targets: [
        .target(
            name: "IFRCore",
            resources: [.copy("Resources/bank-v1.json")]
        ),
        .testTarget(name: "IFRCoreTests", dependencies: ["IFRCore"]),
    ]
)
