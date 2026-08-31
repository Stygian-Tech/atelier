// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "AtelierCalendarSync",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "AtelierCalendarSyncKit", targets: ["AtelierCalendarSyncKit"]),
        .executable(name: "atelier-calendar-sync", targets: ["AtelierCalendarSync"]),
    ],
    dependencies: [
        .package(path: "../../packages/swift"),
        .package(path: "../worker"),
    ],
    targets: [
        .target(
            name: "AtelierCalendarSyncKit",
            dependencies: [
                .product(name: "AtelierJobs", package: "swift"),
                .product(name: "AtelierProviders", package: "swift"),
                .product(name: "AtelierWorkerKit", package: "worker"),
            ],
            swiftSettings: [.swiftLanguageMode(.v6)]
        ),
        .executableTarget(
            name: "AtelierCalendarSync",
            dependencies: [
                "AtelierCalendarSyncKit",
                .product(name: "AtelierWorkerKit", package: "worker"),
            ],
            swiftSettings: [.swiftLanguageMode(.v6)]
        ),
        .testTarget(
            name: "AtelierCalendarSyncKitTests",
            dependencies: [
                "AtelierCalendarSyncKit",
                .product(name: "AtelierJobs", package: "swift"),
                .product(name: "AtelierProviders", package: "swift"),
                .product(name: "AtelierWorkerKit", package: "worker"),
            ],
            swiftSettings: [.swiftLanguageMode(.v6)]
        ),
    ]
)
