// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "AtelierWorker",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "AtelierWorkerKit", targets: ["AtelierWorkerKit"]),
        .executable(name: "atelier-worker", targets: ["AtelierWorker"]),
    ],
    dependencies: [
        .package(path: "../../packages/swift"),
    ],
    targets: [
        .target(
            name: "AtelierWorkerKit",
            dependencies: [
                .product(name: "AtelierJobs", package: "swift"),
            ],
            swiftSettings: [.swiftLanguageMode(.v6)]
        ),
        .executableTarget(
            name: "AtelierWorker",
            dependencies: ["AtelierWorkerKit"],
            swiftSettings: [.swiftLanguageMode(.v6)]
        ),
        .testTarget(
            name: "AtelierWorkerKitTests",
            dependencies: [
                "AtelierWorkerKit",
                .product(name: "AtelierJobs", package: "swift"),
            ],
            swiftSettings: [.swiftLanguageMode(.v6)]
        ),
    ]
)
