// swift-tools-version: 6.2

import PackageDescription

let package = Package(
    name: "Authentication",
    platforms: [
        .iOS(.v17),
        .macOS(.v14)
    ],
    products: [
        // コア抽象（vendor 非依存）。画面はこれだけに依存できる。
        .library(name: "Authentication", targets: ["Authentication"]),
        // SwiftUI（システムのみ）。
        .library(name: "AuthenticationUI", targets: ["AuthenticationUI"]),
        // 資格情報の取得（具象）。
        .library(name: "AuthenticationApple", targets: ["AuthenticationApple"]),
        .library(name: "AuthenticationGoogle", targets: ["AuthenticationGoogle"]),
        // セッション交換（具象）。
        .library(name: "AuthenticationFirebase", targets: ["AuthenticationFirebase"]),
        // ログイン後処理（具象・REST）。
        .library(name: "AuthenticationAPI", targets: ["AuthenticationAPI"])
    ],
    dependencies: [
        .package(url: "https://github.com/no-problem-dev/swift-api-client.git", .upToNextMajor(from: "1.0.0")),
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
            path: "Sources/AuthenticationFirebase"
        ),

        // MARK: - Post-authentication (REST)
        .target(
            name: "AuthenticationAPI",
            dependencies: [
                "Authentication",
                .product(name: "APIClient", package: "swift-api-client")
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
            dependencies: ["AuthenticationAPI"],
            path: "Tests/AuthenticationAPITests"
        )
    ]
)
