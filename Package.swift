// swift-tools-version: 6.4
// The swift-tools-version declares the minimum version of Swift required to build this package.

// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "KinesiaMotion",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [
        .library(name: "KinesiaMotion", targets: ["KinesiaMotion"]),
        .library(name: "KinesiaMotionVision", targets: ["KinesiaMotionVision"]),
        // Development tool: compares Kinesia with a goniometer (`swift run kinesia-validate`).
        .executable(name: "kinesia-validate", targets: ["KinesiaValidate"])
    ],
    targets: [
        .target(name: "KinesiaMotion"),
        .target(name: "KinesiaMotionVision", dependencies: ["KinesiaMotion"]),
        .target(name: "KinesiaValidation", dependencies: ["KinesiaMotion"]),
        .executableTarget(name: "KinesiaValidate", dependencies: ["KinesiaValidation", "KinesiaMotionVision"]),
        .testTarget(name: "KinesiaMotionTests", dependencies: ["KinesiaMotion"]),
        .testTarget(name: "KinesiaMotionVisionTests", dependencies: ["KinesiaMotionVision"]),
        .testTarget(name: "KinesiaValidationTests", dependencies: ["KinesiaValidation"])
    ]
)
