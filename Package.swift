// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "NotchDownloads",
    platforms: [.macOS(.v13)],
    targets: [
        .executableTarget(
            name: "NotchDownloads",
            path: "Sources/NotchDownloads"
        )
    ]
)
