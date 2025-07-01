// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "VoiceChatApp",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(
            name: "VoiceChatApp",
            targets: ["VoiceChatApp"]
        )
    ],
    dependencies: [
        // No external dependencies needed for this basic implementation
    ],
    targets: [
        .executableTarget(
            name: "VoiceChatApp",
            dependencies: [],
            path: ".",
            exclude: [
                "README.md",
                "Info.plist"
            ],
            sources: [
                "VoiceChatApp.swift",
                "ContentView.swift", 
                "ChatManager.swift",
                "GeminiAPI.swift"
            ]
        )
    ]
) 