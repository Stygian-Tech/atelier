// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "AtelierMailWorkspace",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "AtelierAPI", targets: ["AtelierAPI"]),
        .library(name: "AtelierCore", targets: ["AtelierCore"]),
        .library(name: "AtelierATProto", targets: ["AtelierATProto"]),
        .library(name: "AtelierMCP", targets: ["AtelierMCP"]),
        .library(name: "AtelierSync", targets: ["AtelierSync"]),
        .library(name: "AtelierPlatform", targets: ["AtelierPlatform"]),
        .library(name: "AtelierMail", targets: ["AtelierMail"])
    ],
    targets: [
        .target(name: "AtelierCore", path: "packages/swift/AtelierCore/Sources/AtelierCore"),
        .target(
            name: "AtelierATProto",
            dependencies: ["AtelierCore"],
            path: "packages/swift/AtelierATProto/Sources/AtelierATProto"
        ),
        .target(
            name: "AtelierMCP",
            dependencies: ["AtelierCore"],
            path: "packages/swift/AtelierMCP/Sources/AtelierMCP"
        ),
        .target(
            name: "AtelierSync",
            dependencies: ["AtelierCore"],
            path: "packages/swift/AtelierSync/Sources/AtelierSync"
        ),
        .target(
            name: "AtelierPlatform",
            dependencies: ["AtelierCore", "AtelierATProto", "AtelierMCP"],
            path: "packages/swift/AtelierPlatform/Sources/AtelierPlatform"
        ),
        .target(
            name: "AtelierMail",
            dependencies: ["AtelierCore", "AtelierPlatform", "AtelierSync"],
            path: "packages/swift/AtelierMail/Sources/AtelierMail"
        ),
        .executableTarget(
            name: "AtelierAPI",
            dependencies: ["AtelierCore", "AtelierPlatform", "AtelierMail", "AtelierMCP"],
            path: "services/api/Sources/AtelierAPI"
        ),
        .testTarget(
            name: "AtelierAPITests",
            dependencies: ["AtelierAPI", "AtelierCore", "AtelierPlatform", "AtelierMail", "AtelierMCP"],
            path: "services/api/Tests/AtelierAPITests"
        )
    ]
)
