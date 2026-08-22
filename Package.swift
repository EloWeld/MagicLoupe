// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "MagicLoupe",
    platforms: [.macOS(.v14)],
    products: [
        .executable(name: "MagicLoupe", targets: ["MagicLoupe"]),
    ],
    targets: [
        .executableTarget(
            name: "MagicLoupe",
            path: "Sources/MagicLoupe"
        ),
    ]
)
