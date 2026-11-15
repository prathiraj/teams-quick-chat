// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "TeamsQuickChat",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .library(
            name: "TeamsQuickChatCore",
            targets: ["TeamsQuickChatCore"]
        ),
        .executable(
            name: "TeamsQuickChat",
            targets: ["TeamsQuickChatMac"]
        )
    ],
    targets: [
        .target(
            name: "TeamsQuickChatCore",
            path: "Sources/TeamsQuickChatCore"
        ),
        .executableTarget(
            name: "TeamsQuickChatMac",
            dependencies: ["TeamsQuickChatCore"],
            path: "Sources/TeamsQuickChatMac"
        ),
        .testTarget(
            name: "TeamsQuickChatCoreTests",
            dependencies: ["TeamsQuickChatCore"],
            path: "Tests/TeamsQuickChatCoreTests"
        )
    ]
)
