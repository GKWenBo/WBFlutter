// swift-tools-version: 5.9
// Swift Package Manager 描述文件。Flutter 3.44 的 iOS 工程已启用 SPM，
// 插件只要在 ios/<插件名>/Package.swift 提供包，就会被 Flutter 自动接进
// FlutterGeneratedPluginSwiftPackage。
import PackageDescription

let package = Package(
    name: "nl_sign_kit",
    platforms: [
        .iOS("13.0")
    ],
    products: [
        // ★ 产品名必须和 Flutter 的约定一致：插件名里的下划线换成连字符。
        // Flutter 生成的总包会依赖 .product(name: "nl-sign-kit", package: "nl_sign_kit")。
        .library(name: "nl-sign-kit", targets: ["nl_sign_kit"])
    ],
    dependencies: [
        .package(name: "FlutterFramework", path: "../FlutterFramework")
    ],
    targets: [
        // 纯 C target：编译 forwarder（它 #include 了插件根目录的 src/nl_sign_kit.c），
        // 这样 Android 和 iOS 共用一份 C 源码。
        .target(
            name: "nl_sign_kit_c",
            path: "Sources/nl_sign_kit_c",
            publicHeadersPath: "include"
        ),
        // Swift 侧只有一个作用：在 register 时“碰”一下 C 符号，
        // 保证静态链接时 C 目标文件不被裁掉。
        .target(
            name: "nl_sign_kit",
            dependencies: [
                "nl_sign_kit_c",
                .product(name: "FlutterFramework", package: "FlutterFramework")
            ]
        )
    ]
)
