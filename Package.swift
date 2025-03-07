// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "SFDialPlateSDK",
    platforms: [
        .iOS(.v9), // 设置 iOS 的最低支持版本为 9.0
    ],
    products: [
        // Products define the executables and libraries a package produces, making them visible to other packages.
        .library(
            name: "SFDialPlateSDK",
            targets: ["SFDialPlateSDK"]),
    ],
    dependencies: [
        // 添加对 Zip 库的依赖
        .package(url: "https://github.com/marmelroy/Zip.git", from: "2.1.0"),
        // 注意：这里使用了 from: "2.1.0" 而不是 .upToNextMinor(from: "2.1")，
        // 因为 .upToNextMinor 不是一个有效的 Swift Package Manager 语法。
        // 如果你确实想要自动更新到下一个次要版本，可以使用 from: 并省略具体的次版本号，
        // 但这通常不推荐用于生产环境，因为它可能导致不可预见的变更。
        // 如果你确实需要类似 .upToNextMinor 的功能，你需要在版本发布后手动更新。
    ],
    targets: [
        // Targets are the basic building blocks of a package, defining a module or a test suite.
        // Targets can depend on other targets in this package and products from dependencies.
        .target(
            name: "SFDialPlateSDK",
            dependencies: ["Zip"], // 依赖声明
            path: "Sources/SFDialPlateSDK" // 显式路径声明（可选）
        ),
        .testTarget(
            name: "SFDialPlateSDKTests",
            dependencies: ["SFDialPlateSDK"]
        ),
    ]
)
