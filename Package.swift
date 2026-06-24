// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "NexVoice",
    defaultLocalization: "en",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .library(name: "NexVoiceCore", targets: ["NexVoiceCore"]),
        .executable(name: "NexVoiceApp", targets: ["NexVoiceHost"])
    ],
    dependencies: [
        .package(url: "https://github.com/argmaxinc/argmax-oss-swift.git", from: "1.0.0")
    ],
    targets: [
        .target(
            name: "NexVoiceCore",
            path: "Sources/NexVoiceCore"
        ),
        .executableTarget(
            name: "NexVoiceHost",
            dependencies: [
                "NexVoiceCore",
                .product(name: "WhisperKit", package: "argmax-oss-swift")
            ],
            path: "Sources/NexVoiceHost"
        ),
        .testTarget(
            name: "NexVoiceCoreTests",
            dependencies: ["NexVoiceCore"],
            path: "Tests/NexVoiceCoreTests"
        )
    ]
)
