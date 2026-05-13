// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "SpotTerminal",
    defaultLocalization: "en",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "SpotTerminal", targets: ["SpotTerminal"])
    ],
    dependencies: [
        .package(url: "https://github.com/migueldeicaza/SwiftTerm.git", from: "1.0.0")
    ],
    targets: [
        .executableTarget(
            name: "SpotTerminal",
            dependencies: [
                .product(name: "SwiftTerm", package: "SwiftTerm")
            ],
            path: "Sources/SpotTerminal",
            resources: [
                .process("Resources")
            ],
            linkerSettings: [
                .linkedFramework("AppKit"),
                .linkedFramework("ApplicationServices"),
                .linkedFramework("CoreGraphics"),
                .linkedFramework("SwiftUI")
            ]
        ),
        .testTarget(
            name: "SpotTerminalTests",
            dependencies: ["SpotTerminal"],
            path: "Tests/SpotTerminalTests"
        )
    ]
)
