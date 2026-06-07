// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "TouchTouch",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(name: "TouchTouch", targets: ["TouchTouch"]),
        .executable(name: "kb-brightness", targets: ["kb-brightness"])
    ],
    targets: [
        .executableTarget(
            name: "TouchTouch",
            path: "Sources/TouchTouch"
        ),
        .executableTarget(
            name: "kb-brightness",
            path: "Sources/kb-brightness"
        ),
        .testTarget(
            name: "TouchTouchTests",
            dependencies: ["TouchTouch"],
            path: "Tests/TouchTouchTests"
        )
    ]
)
