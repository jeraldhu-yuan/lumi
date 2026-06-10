// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "CodexDesktopSprite",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "Sprite", targets: ["CodexSprite"])
    ],
    dependencies: [],
    targets: [
        .executableTarget(
            name: "CodexSprite",
            path: "Sources/CodexSprite"
        )
    ]
)
