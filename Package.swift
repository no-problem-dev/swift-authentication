// swift-tools-version: 6.2

import PackageDescription

let package = Package(
    name: "Authentication",
    platforms: [
        .iOS(.v17),
        .macOS(.v14)
    ],
    products: [
        // Core abstractions, free of vendor SDKs. Screens can depend on this alone.
        .library(name: "Authentication", targets: ["Authentication"]),
        // Sessions issued by the app's own server. The default authenticator.
        .library(name: "AuthenticationSession", targets: ["AuthenticationSession"]),
        // SwiftUI views, system frameworks only.
        .library(name: "AuthenticationUI", targets: ["AuthenticationUI"]),
        // Credential acquisition.
        .library(name: "AuthenticationApple", targets: ["AuthenticationApple"]),
        .library(name: "AuthenticationGoogle", targets: ["AuthenticationGoogle"])
    ],
    dependencies: [
        // The one SDK in the package, used by AuthenticationGoogle alone.
        .package(url: "https://github.com/google/GoogleSignIn-iOS.git", .upToNextMajor(from: "9.0.0")),
    ],
    targets: [
        // MARK: - Core (no third-party dependencies)
        .target(
            name: "Authentication",
            path: "Sources/Authentication"
        ),

        // MARK: - Session (Foundation and Security only)
        .target(
            name: "AuthenticationSession",
            dependencies: ["Authentication"],
            path: "Sources/AuthenticationSession"
        ),

        // MARK: - UI (SwiftUI + system frameworks only)
        .target(
            name: "AuthenticationUI",
            dependencies: ["Authentication"],
            path: "Sources/AuthenticationUI",
            resources: [.process("Resources")]
        ),

        // MARK: - Credential providers
        .target(
            name: "AuthenticationApple",
            dependencies: ["Authentication"],
            path: "Sources/AuthenticationApple"
        ),
        .target(
            name: "AuthenticationGoogle",
            dependencies: [
                "Authentication",
                .product(name: "GoogleSignIn", package: "GoogleSignIn-iOS")
            ],
            path: "Sources/AuthenticationGoogle"
        ),

        // MARK: - Tests
        .testTarget(
            name: "AuthenticationTests",
            dependencies: ["Authentication"],
            path: "Tests/AuthenticationTests"
        ),
        .testTarget(
            name: "AuthenticationSessionTests",
            dependencies: ["AuthenticationSession", "Authentication"],
            path: "Tests/AuthenticationSessionTests"
        ),
        .testTarget(
            name: "AuthenticationAppleTests",
            dependencies: ["AuthenticationApple"],
            path: "Tests/AuthenticationAppleTests"
        )
    ]
)
