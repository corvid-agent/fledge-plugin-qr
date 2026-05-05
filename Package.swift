// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "fledge-qr",
    platforms: [.macOS(.v12)],
    targets: [
        .executableTarget(
            name: "fledge-qr",
            linkerSettings: [
                .linkedFramework("CoreImage"),
                .linkedFramework("CoreGraphics"),
            ]
        ),
    ]
)
