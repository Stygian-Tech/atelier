// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "AtelierAPI",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "AtelierAPIKit", targets: ["AtelierAPIKit"]),
        .executable(name: "atelier-api", targets: ["AtelierAPI"]),
    ],
    dependencies: [
        .package(path: "../../packages/swift"),
        .package(url: "https://github.com/hummingbird-project/hummingbird.git", from: "2.6.0"),
        .package(url: "https://github.com/apple/swift-http-types.git", from: "1.3.0"),
    ],
    targets: [
        .target(
            name: "AtelierAPIKit",
            dependencies: [
                .product(name: "AtelierContracts", package: "swift"),
                .product(name: "AtelierProviders", package: "swift"),
                .product(name: "Hummingbird", package: "hummingbird"),
                .product(name: "HTTPTypes", package: "swift-http-types"),
            ],
            swiftSettings: [.swiftLanguageMode(.v6)]
        ),
        .executableTarget(
            name: "AtelierAPI",
            dependencies: ["AtelierAPIKit", .product(name: "Hummingbird", package: "hummingbird")],
            swiftSettings: [.swiftLanguageMode(.v6)]
        ),
        .testTarget(
            name: "AtelierAPIKitTests",
            dependencies: [
                "AtelierAPIKit",
                .product(name: "Hummingbird", package: "hummingbird"),
                .product(name: "HummingbirdTesting", package: "hummingbird"),
                .product(name: "HTTPTypes", package: "swift-http-types"),
            ],
            swiftSettings: [.swiftLanguageMode(.v6)]
        ),
    ]
)
