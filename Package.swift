// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "PhotoEditorMac",
    defaultLocalization: "en",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "PhaseOnePhotoEditor", targets: ["PhaseOnePhotoEditor"])
    ],
    targets: [
        .executableTarget(
            name: "PhaseOnePhotoEditor",
            path: "Sources/PhaseOnePhotoEditor",
            linkerSettings: [
                .linkedFramework("AppKit"),
                .linkedFramework("Metal"),
                .linkedFramework("Network"),
                .linkedFramework("SwiftUI")
            ]
        ),
        .testTarget(
            name: "PhaseOnePhotoEditorTests",
            dependencies: ["PhaseOnePhotoEditor"],
            path: "Tests/PhaseOnePhotoEditorTests"
        )
    ]
)
