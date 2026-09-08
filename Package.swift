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
        // SwiftUI views, system frameworks only.
        .library(name: "AuthenticationUI", targets: ["AuthenticationUI"]),
        // Credential acquisition.
        .library(name: "AuthenticationApple", targets: ["AuthenticationApple"]),
        .library(name: "AuthenticationGoogle", targets: ["AuthenticationGoogle"]),
        // Session exchange.
        .library(name: "AuthenticationFirebase", targets: ["AuthenticationFirebase"]),
        // Post-authentication work, over REST.
        .library(name: "AuthenticationAPI", targets: ["AuthenticationAPI"])
    ],
    dependencies: [
        .package(url: "https://github.com/no-problem-dev/swift-api-client.git", from: "6.0.0"),
        // api-client 3.0.3 stopped re-exporting APIContract, so the contract types this package
        // declares in its own public API have to be depended on directly.
        .package(url: "https://github.com/no-problem-dev/swift-api-contract.git", from: "2.0.0"),
        .package(url: "https://github.com/firebase/firebase-ios-sdk.git", .upToNextMajor(from: "12.5.0")),
        .package(url: "https://github.com/google/GoogleSignIn-iOS.git", .upToNextMajor(from: "9.0.0")),
        .package(url: "https://github.com/swiftlang/swift-docc-plugin", .upToNextMajor(from: "1.4.0"))
    ],
    targets: [
        // MARK: - Core (no third-party dependencies)
        .target(
            name: "Authentication",
            path: "Sources/Authentication"
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

        // MARK: - Session exchange (Firebase)
        .target(
            name: "AuthenticationFirebase",
            dependencies: [
                "Authentication",
                .product(name: "FirebaseAuth", package: "firebase-ios-sdk"),
                .product(name: "FirebaseCore", package: "firebase-ios-sdk")
            ],
            path: "Sources/AuthenticationFirebase",
            // The privacy manifest lives here alone, because this is the only target that
            // touches user defaults. `.copy` puts it in the bundle verbatim.
            resources: [.copy("PrivacyInfo.xcprivacy")]
        ),

        // MARK: - Post-authentication (REST)
        .target(
            name: "AuthenticationAPI",
            dependencies: [
                "Authentication",
                .product(name: "APIClient", package: "swift-api-client"),
                .product(name: "APIContract", package: "swift-api-contract")
            ],
            path: "Sources/AuthenticationAPI"
        ),

        // MARK: - Tests
        .testTarget(
            name: "AuthenticationTests",
            dependencies: ["Authentication"],
            path: "Tests/AuthenticationTests"
        ),
        .testTarget(
            name: "AuthenticationAppleTests",
            dependencies: ["AuthenticationApple"],
            path: "Tests/AuthenticationAppleTests"
        ),
        .testTarget(
            name: "AuthenticationAPITests",
            dependencies: [
                "AuthenticationAPI",
                .product(name: "APIContract", package: "swift-api-contract")
            ],
            path: "Tests/AuthenticationAPITests"
        ),
        .testTarget(
            name: "AuthenticationFirebaseTests",
            dependencies: ["AuthenticationFirebase", "Authentication"],
            path: "Tests/AuthenticationFirebaseTests"
        )
    ]
)
