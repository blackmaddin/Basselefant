// swift-tools-version: 5.10
import PackageDescription

let package = Package(
    name: "Basselefant",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(name: "BasselefantApp", targets: ["BasselefantApp"]),
        .executable(name: "IconGenerator", targets: ["IconGenerator"])
    ],
    targets: [
        .executableTarget(
            name: "BasselefantApp",
            path: "Sources/BasselefantApp",
            linkerSettings: [
                .linkedFramework("AVFoundation"),
                .linkedFramework("Accelerate"),
                .linkedFramework("AppKit")
            ]
        ),
        .executableTarget(
            name: "IconGenerator",
            path: "Sources/IconGenerator",
            linkerSettings: [
                .linkedFramework("AppKit")
            ]
        )
    ]
)
