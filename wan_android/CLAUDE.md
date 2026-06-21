# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## 项目背景

这是一个**教学项目**：带一位资深 iOS 工程师从 0→1 实战学 Flutter。最终产物是电商 App「WanShop」（工程包名仍叫 `wan_android`，App 显示名为 WanShop）。

代码不是为了最快交付，而是为了**讲清楚**。这决定了几条非显而易见的规范：

- 注释面向 iOS/SwiftUI 背景的读者，**用类比讲原理**（如 `StatefulWidget` ≈ 带 `@State` 的 SwiftUI View、`MaterialApp` ≈ AppDelegate+UIWindow、`NavigationBar` ≈ UITabBar）。新增代码应保持同样的注释密度与类比风格。
- 注释里常出现 `M2 / M4 / M5 …` 这类标记，指课程后续模块（见下）。占位实现（假数据、空 `onTap`）会显式注明"哪个模块替换它"，**不要擅自补全成真实功能**——那是后续模块的内容。

## 常用命令

```bash
flutter pub get                 # 拉依赖
flutter run                     # 跑到模拟器/真机（热重载默认开）
flutter analyze                 # 静态检查（lint，提交前必跑）
flutter test                    # 跑全部测试
flutter test test/widget_test.dart            # 跑单个测试文件
flutter test --name '关键字'                   # 按测试名筛选
```

## 架构

**feature-first 分层**，目录约定：

```
lib/
  main.dart            # 极薄入口，只 runApp(WanShopApp())，不放装配逻辑
  app/                 # 全局装配
    app.dart           #   WanShopApp：MaterialApp、主题、（以后）路由表
    main_scaffold.dart #   MainScaffold：底部 4-Tab（≈ UITabBarController）
  core/                # 跨 feature 的通用代码（网络/主题/工具，后续模块引入）
  features/<name>/     # 每个业务模块自成一体，互不依赖
    data/ domain/ presentation/   # feature 内再分三层
```

关键约定：

- **`main.dart` 保持极薄**——只负责启动。主题、首页、路由等装配全在 `app/app.dart`，这样后续接 Riverpod 的 `ProviderScope`、go_router 时改动点集中。
- **每个 Tab 页面来自各自的 feature 目录，彼此不 import**。`MainScaffold` 用 `IndexedStack` 让 4 个页面常驻、保留各自滚动位置。
- **页面优先 `StatelessWidget`**，把可变状态下沉封装到子 Widget（例：首页是 Stateless，Banner 当前页状态封在 `HomeBanner` 里，不污染首页）。
- 列表/网格用 `CustomScrollView` + Sliver 组合，整页单一滚动容器。

### 技术选型（已定，不要再问）

- 状态管理：**Riverpod** 3.x + `riverpod_annotation` 代码生成（M4 引入，尚未加入依赖）
- 网络：**dio**，数据源 **DummyJSON**（`https://dummyjson.com`，测试账号 `emilys` / `emilyspass`）
- 路由：**go_router**（M5 引入）

目前 `pubspec.yaml` 仅有 `cupertino_icons` + `flutter_lints`，上述库按模块进度逐步加入。

## 课程模块进度

完整大纲见 `/Users/wenbo/.claude/plans/generic-skipping-bubble.md`（M0–M13）。

- ✅ M0 4-Tab 骨架 + 目录结构
- ✅ M1 首页静态 UI（搜索框 / Banner / 分类入口 / 商品网格，本地假数据用 Dart record）
- ⬜ M2 数据建模 → M3 dio → M4 Riverpod+三态 → M5 go_router → M6 分类搜索 → M7 购物车 → M8 登录鉴权 → M9 收藏/缓存 → M10 下单 → M11 测试 → M12 发布 → M13 性能

## Git 约定（重要）

- 仓库根是 `/Users/wenbo/Desktop/WBFlutter`（**不是** `wan_android/`）。提交时**只 `git add wan_android/`**，避免把 `../Dart/` 等无关旧改动一起带进来。
- 直接提交到 `main`（线性学习日志风格）。提交信息用**中文、按模块**组织（如 `M1 首页静态 UI：…`）。
