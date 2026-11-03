// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "Kikobar",
    defaultLocalization: "en",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(
            name: "Kikobar",
            targets: ["Kikobar"]
        )
    ],
    dependencies: [],
    targets: [
        .executableTarget(
            name: "Kikobar",
            dependencies: [],
            path: "Sources/Kikobar",
            resources: [],
            swiftSettings: [
                .unsafeFlags([
                    "-plugin-path",
                    "/Applications/Xcode.app/Contents/Developer/Platforms/MacOSX.platform/Developer/usr/lib/swift/host/plugins"
                ])
            ]
        ),
        .testTarget(
            name: "KikobarTests",
            dependencies: ["Kikobar"],
            path: "Tests/KikobarTests",
            swiftSettings: [
                .unsafeFlags([
                    "-plugin-path",
                    "/Applications/Xcode.app/Contents/Developer/Platforms/MacOSX.platform/Developer/usr/lib/swift/host/plugins",
                    "-plugin-path",
                    "/Library/Developer/CommandLineTools/usr/lib/swift/host/plugins/testing"
                ])
            ]
        )
    ]
)
