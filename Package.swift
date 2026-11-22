// swift-tools-version:5.9
import PackageDescription

// The module is named AppCore so the product name lives only in
// Config/App.xcconfig; scripts/bundle.sh wraps the binary in <APP_NAME>.app.
let package = Package(
    name: "AppCore",
    platforms: [.macOS("15.0")],
    targets: [
        .executableTarget(
            name: "AppCore",
            path: "Sources"
        ),
        .testTarget(
            name: "AppCoreTests",
            dependencies: ["AppCore"],
            path: "Tests"
        ),
    ]
)
