// swift-tools-version: 6.0
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "Authentication",
    platforms: [
        .iOS(.v17),
        .macOS(.v14)
    ],
    products: [
        .library(
            name: "Authentication",
            targets: ["Authentication"]
        )
    ],
    dependencies: [
        .package(url: "https://github.com/no-problem-dev/swift-api-client.git", .upToNextMajor(from: "1.0.0")),
        .package(url: "https://github.com/firebase/firebase-ios-sdk.git", .upToNextMajor(from: "12.5.0")),
        .package(url: "https://github.com/google/GoogleSignIn-iOS.git", .upToNextMajor(from: "9.0.0")),
        .package(url: "https://github.com/swiftlang/swift-docc-plugin", .upToNextMajor(from: "1.4.0"))
    ],
    targets: [
        .target(
            name: "Authentication",
            dependencies: [
                .product(name: "APIClient", package: "swift-api-client"),
                .product(name: "FirebaseAuth", package: "firebase-ios-sdk"),
                .product(name: "GoogleSignIn", package: "GoogleSignIn-iOS")
            ],
            path: "Sources/Authentication",
            resources: [
                .process("Resources")
            ]
        ),
        .testTarget(
            name: "AuthenticationTests",
            dependencies: ["Authentication"],
            path: "Tests/AuthenticationTests"
        )
    ]
)
