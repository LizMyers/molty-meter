// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "MoltyMeter",
    platforms: [.macOS(.v13)],
    targets: [
        .executableTarget(
            name: "MoltyMeter",
            path: "MoltyMeter",
            exclude: ["Info.plist"],
            // Link Info.plist into the binary's __TEXT,__info_plist section so
            // Bundle.main.infoDictionary actually reflects it at runtime — without this,
            // `exclude` above meant the plist was never embedded at all, so the app had
            // no real single source of truth for its own version (see the v1.3-displayed-
            // while-README-says-v1.5 bug).
            linkerSettings: [
                .unsafeFlags([
                    "-Xlinker", "-sectcreate",
                    "-Xlinker", "__TEXT",
                    "-Xlinker", "__info_plist",
                    "-Xlinker", "MoltyMeter/Info.plist"
                ])
            ]
        )
    ]
)
