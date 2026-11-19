// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "Siliconium",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(name: "Siliconium", path: "Sources/Siliconium")
    ]
)
