// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "AtelierMCPBackplane",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "AtelierMCPBackplaneKit", targets: ["AtelierMCPBackplaneKit"]),
        .executable(name: "atelier-mcp-backplane", targets: ["AtelierMCPBackplane"]),
    ],
    dependencies: [
        .package(path: "../../packages/swift"),
        .package(url: "https://github.com/hummingbird-project/hummingbird.git", from: "2.6.0"),
        .package(url: "https://github.com/apple/swift-http-types.git", from: "1.3.0"),
        .package(url: "https://github.com/apple/swift-crypto.git", exact: "3.15.1"),
    ],
    targets: [
        .target(
            name: "AtelierMCPBackplaneKit",
            dependencies: [
                .product(name: "AtelierContracts", package: "swift"),
                .product(name: "AtelierMCP", package: "swift"),
                .product(name: "Crypto", package: "swift-crypto"),
                .product(name: "Hummingbird", package: "hummingbird"),
                .product(name: "HTTPTypes", package: "swift-http-types"),
            ],
            swiftSettings: [.swiftLanguageMode(.v6)]
        ),
        .executableTarget(
            name: "AtelierMCPBackplane",
            dependencies: ["AtelierMCPBackplaneKit", .product(name: "Hummingbird", package: "hummingbird")],
            swiftSettings: [.swiftLanguageMode(.v6)]
        ),
        .testTarget(
            name: "AtelierMCPBackplaneKitTests",
            dependencies: [
                "AtelierMCPBackplaneKit",
                .product(name: "AtelierContracts", package: "swift"),
                .product(name: "AtelierMCP", package: "swift"),
                .product(name: "Hummingbird", package: "hummingbird"),
                .product(name: "HummingbirdTesting", package: "hummingbird"),
                .product(name: "HTTPTypes", package: "swift-http-types"),
            ],
            swiftSettings: [.swiftLanguageMode(.v6)]
        ),
    ]
)
