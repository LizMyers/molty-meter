// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "MoltyMeter",
    platforms: [.macOS(.v13)],
    targets: [
        .executableTarget(
            name: "MoltyMeter",
            path: "MoltyMeter",
            exclude: ["Info.plist"]
        )
    ]
)
