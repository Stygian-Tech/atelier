// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "AtelierSwift",
    platforms: [.macOS(.v14), .iOS(.v17)],
    products: [
        .library(name: "AtelierContracts", targets: ["AtelierContracts"]),
        .library(name: "AtelierATProto", targets: ["AtelierATProto"]),
        .library(name: "AtelierJobs", targets: ["AtelierJobs"]),
        .library(name: "AtelierProviders", targets: ["AtelierProviders"]),
        .library(name: "AtelierMCP", targets: ["AtelierMCP"]),
    ],
    dependencies: [
        .package(
            url: "https://github.com/Stygian-Tech/atproto-primitive-kit.git",
            revision: "1105fb3c008a1048c40b9d1b71cc2cc8e51319b0"
        ),
        .package(
            url: "https://github.com/apple/swift-crypto.git",
            exact: "3.15.1"
        ),
    ],
    targets: [
        .target(name: "AtelierContracts", swiftSettings: [.swiftLanguageMode(.v6)]),
        .target(
            name: "AtelierATProto",
            dependencies: [
                .product(name: "ATProtoPrimitiveKit", package: "atproto-primitive-kit"),
                .product(name: "Crypto", package: "swift-crypto"),
            ],
            swiftSettings: [.swiftLanguageMode(.v6)]
        ),
        .target(name: "AtelierJobs", dependencies: ["AtelierContracts"], swiftSettings: [.swiftLanguageMode(.v6)]),
        .target(name: "AtelierProviders", dependencies: ["AtelierContracts"], swiftSettings: [.swiftLanguageMode(.v6)]),
        .target(name: "AtelierMCP", dependencies: ["AtelierContracts"], swiftSettings: [.swiftLanguageMode(.v6)]),
        .testTarget(
            name: "AtelierSwiftTests",
            dependencies: [
                "AtelierATProto",
                "AtelierContracts",
                "AtelierJobs",
                "AtelierProviders",
                "AtelierMCP",
                .product(name: "Crypto", package: "swift-crypto"),
            ],
            swiftSettings: [.swiftLanguageMode(.v6)]
        ),
    ]
)
