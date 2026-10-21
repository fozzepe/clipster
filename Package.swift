// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "Clipster",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(name: "Clipster", path: "Sources/Clipster")
    ]
)
