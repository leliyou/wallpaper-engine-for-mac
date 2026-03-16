// swift-tools-version: 5.8
import PackageDescription

let package = Package(
    name: "WallpaperEnginePrototype",
    platforms: [
        .macOS(.v12)
    ],
    products: [
        .executable(
            name: "WallpaperEnginePrototype",
            targets: ["WallpaperPrototypeApp"]
        )
    ],
    targets: [
        .executableTarget(
            name: "WallpaperPrototypeApp",
            path: "Sources/WallpaperPrototypeApp"
        )
    ]
)
