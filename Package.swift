// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "fledge-qr",
    platforms: [.macOS(.v14)],
    dependencies: [
        .package(url: "https://github.com/CorvidLabs/swift-qr.git", from: "0.1.0"),
    ],
    targets: [
        .executableTarget(
            name: "fledge-qr",
            dependencies: [
                .product(name: "SwiftQR", package: "swift-qr"),
            ]
        ),
    ]
)
