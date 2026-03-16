// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "Stim",
    platforms: [.macOS(.v13)],
    targets: [
        .executableTarget(
            name: "Stim",
            path: "Sources",
            linkerSettings: [
                .linkedFramework("IOKit")
            ]
        )
    ]
)
