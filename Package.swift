// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "Javira",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(name: "Javira", targets: ["Javira"]),
        .executable(name: "JaviraTests", targets: ["JaviraTests"])
    ],
    targets: [
        .executableTarget(
            name: "Javira",
            path: "Javira",
            exclude: ["Info.plist", "Javira.entitlements", "Tests"]
        ),
        .executableTarget(
            name: "JaviraTests",
            path: "Tests"
        )
    ]
)
