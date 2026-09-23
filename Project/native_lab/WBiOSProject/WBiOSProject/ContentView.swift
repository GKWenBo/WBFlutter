//
//  ContentView.swift
//  WBiOSProject
//
//  Created by 文波 on 2026/7/25.
//

import SwiftUI

/// 宿主 App 的原生首页（SwiftUI）。
/// 剧情：这是"公司已有的原生 App"，现在要接 Flutter。
/// 三个入口分别对应 L8 冷启动、L9 预热+路由、L9 反向通信。
struct ContentView: View {
    /// nil = 不展示 Flutter 页；非 nil = 展示，并携带要打开的模式。
    @State private var presented: FlutterEntry?
    /// 原生问模块要来的状态（L9 反向通信结果）。
    @State private var moduleState: String?

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Text("这是一个【原生 iOS App】（SwiftUI）。\nFlutter 模块通过 CocoaPods 接了进来——下面每个入口打开的都是 Flutter 画的页面。")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                Section("L8 · 原生工程接入 Flutter") {
                    Button {
                        presented = .cold
                    } label: {
                        Label {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("冷启动打开 Flutter 页")
                                Text("每次新建引擎 · 注意首屏那段白屏")
                                    .font(.caption).foregroundStyle(.secondary)
                            }
                        } icon: { Image(systemName: "tortoise") }
                    }
                }

                Section("L9 · 引擎管理与通信") {
                    Button {
                        presented = .warm(route: "/")
                    } label: {
                        Label {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("预热引擎打开（秒开）")
                                Text("复用常驻引擎 · 对比上面的白屏")
                                    .font(.caption).foregroundStyle(.secondary)
                            }
                        } icon: { Image(systemName: "hare") }
                    }

                    Button {
                        presented = .warm(route: "/detail")
                    } label: {
                        Label {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("由原生指定打开 /detail")
                                Text("通道驱动 Navigator · 混合路由协调")
                                    .font(.caption).foregroundStyle(.secondary)
                            }
                        } icon: { Image(systemName: "arrow.triangle.branch") }
                    }

                    Button {
                        // 原生 → Flutter 的反向调用：宿主主动问模块当前状态。
                        FlutterHostEngine.shared.queryModuleState { state in
                            moduleState = state
                        }
                    } label: {
                        Label("原生反问模块：你现在什么状态？",
                              systemImage: "arrow.uturn.backward")
                    }

                    if let moduleState {
                        Text("模块答：\(moduleState)")
                            .font(.footnote)
                            .foregroundStyle(.tint)
                    }
                }
            }
            .navigationTitle("WBiOSProject")
        }
        // 用 fullScreenCover 整屏展示 Flutter——对照 L4 的"页面级混合"，
        // 只是这次角色调换：原生是宿主，Flutter 是被 present 的那一方。
        .fullScreenCover(item: $presented) { entry in
            switch entry {
            case .cold:
                ColdFlutterPage { presented = nil }.ignoresSafeArea()
            case .warm(let route):
                WarmFlutterPage(route: route) { presented = nil }
                    .ignoresSafeArea()
            }
        }
    }
}

/// 要打开哪种 Flutter 页。Identifiable 是 fullScreenCover(item:) 的要求。
enum FlutterEntry: Identifiable {
    case cold
    case warm(route: String)

    var id: String {
        switch self {
        case .cold: return "cold"
        case .warm(let route): return "warm:\(route)"
        }
    }
}

#Preview {
    ContentView()
}
