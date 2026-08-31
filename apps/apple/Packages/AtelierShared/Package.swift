// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "AtelierShared",
    platforms: [
        .iOS(.v17),
        .macOS(.v14),
    ],
    products: [
        .library(name: "AtelierCore", targets: ["AtelierCore"]),
        .library(name: "AtelierContracts", targets: ["AtelierContracts"]),
        .library(name: "AtelierPersistence", targets: ["AtelierPersistence"]),
        .library(name: "AtelierCollaboration", targets: ["AtelierCollaboration"]),
        .library(name: "AtelierEditor", targets: ["AtelierEditor"]),
        .library(name: "AtelierDesign", targets: ["AtelierDesign"]),
        .library(name: "AtelierAppUI", targets: ["AtelierAppUI"]),
    ],
    targets: [
        .target(name: "AtelierCore"),
        .target(name: "AtelierContracts", dependencies: ["AtelierCore"]),
        .target(name: "AtelierPersistence", dependencies: ["AtelierCore"]),
        .target(name: "AtelierCollaboration", dependencies: ["AtelierCore"]),
        .target(
            name: "AtelierEditor",
            resources: [.process("Resources")]
        ),
        .target(name: "AtelierDesign", dependencies: ["AtelierCore"]),
        .target(
            name: "AtelierAppUI",
            dependencies: [
                "AtelierCore",
                "AtelierContracts",
                "AtelierPersistence",
                "AtelierCollaboration",
                "AtelierEditor",
                "AtelierDesign",
            ],
            resources: [.process("Resources")]
        ),
        .testTarget(name: "AtelierCoreTests", dependencies: ["AtelierCore"]),
        .testTarget(name: "AtelierContractsTests", dependencies: ["AtelierContracts"]),
        .testTarget(name: "AtelierPersistenceTests", dependencies: ["AtelierPersistence"]),
        .testTarget(name: "AtelierCollaborationTests", dependencies: ["AtelierCollaboration"]),
        .testTarget(name: "AtelierEditorTests", dependencies: ["AtelierEditor"]),
    ]
)
