//
//  WBiOSProjectApp.swift
//  WBiOSProject
//
//  Created by 文波 on 2026/7/25.
//

import SwiftUI
import UIKit

@main
struct WBiOSProjectApp: App {
    // L9：SwiftUI 没有 AppDelegate，但预热引擎要在"App 启动那一刻"做。
    // @UIApplicationDelegateAdaptor 就是 SwiftUI 通往 UIKit 生命周期的桥。
    // （Flutter 官方 add-to-app 文档里的预热代码写在 AppDelegate，就是这里。）
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}

/// 宿主 App 的 UIKit 生命周期代理。唯一职责：启动时预热 Flutter 引擎。
class AppDelegate: NSObject, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        // ★ 预热：现在花掉引擎启动的时间，换用户点开时的秒开。
        //   代价是 App 常驻多一份 Flutter 引擎的内存（L9 讲义里展开这个取舍）。
        FlutterHostEngine.shared.warmUp()
        return true
    }
}
