// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "AtelierMailSync",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "AtelierMailSyncKit", targets: ["AtelierMailSyncKit"]),
        .executable(name: "atelier-mail-sync", targets: ["AtelierMailSync"]),
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-crypto.git", exact: "3.15.1"),
        .package(path: "../../packages/swift"),
        .package(path: "../worker"),
    ],
    targets: [
        .target(
            name: "AtelierMailSyncKit",
            dependencies: [
                .product(name: "AtelierJobs", package: "swift"),
                .product(name: "AtelierProviders", package: "swift"),
                .product(name: "AtelierWorkerKit", package: "worker"),
                .product(name: "Crypto", package: "swift-crypto"),
            ],
            swiftSettings: [.swiftLanguageMode(.v6)]
        ),
        .executableTarget(
            name: "AtelierMailSync",
            dependencies: [
                "AtelierMailSyncKit",
                .product(name: "AtelierWorkerKit", package: "worker"),
            ],
            swiftSettings: [.swiftLanguageMode(.v6)]
        ),
        .testTarget(
            name: "AtelierMailSyncKitTests",
            dependencies: [
                "AtelierMailSyncKit",
                .product(name: "AtelierJobs", package: "swift"),
                .product(name: "AtelierProviders", package: "swift"),
                .product(name: "AtelierWorkerKit", package: "worker"),
            ],
            swiftSettings: [.swiftLanguageMode(.v6)]
        ),
    ]
)
