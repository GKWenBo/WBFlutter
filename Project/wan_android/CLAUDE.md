# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## 项目背景

这是一个**教学项目**：带一位资深 iOS 工程师从 0→1 实战学 Flutter。产物是电商 App「WanShop」（工程包名仍叫 `wan_android`，App 显示名为 WanShop）。

**课程 M0–M13 已全部完成**（每个模块对应一次 git 提交）。现在的改动属于**维护/回顾阶段**，不是新课时开发。

代码不是为了最快交付，而是为了**讲清楚**。这决定了几条非显而易见的规范：

- 注释面向 iOS/SwiftUI 背景的读者，**用类比讲原理**（如 `StatefulWidget` ≈ 带 `@State` 的 SwiftUI View、`StatefulShellRoute` ≈ UITabBarController、`flutter_secure_storage` ≈ Keychain）。新增代码应保持同样的注释密度与类比风格。
- 注释里的 `M2 / M4 / M13 …` 标记指课程模块，用于说明"这段代码是哪一课引入的、当时为什么这么写"。**这些是历史标注，不要清理掉**——它们是教学价值的一部分。
- 改动已完成模块的代码时，同步检查 `docs/lessons/M*.md` 里的代码地图是否还对得上。

## 常用命令

```bash
flutter pub get                 # 拉依赖
flutter run                     # 跑到模拟器/真机（默认 dev 环境）
flutter analyze                 # 静态检查（lint，提交前必跑）
flutter test                    # 跑全部单元/Widget/golden 测试
flutter test test/cart_test.dart              # 跑单个测试文件
flutter test --name '关键字'                   # 按测试名筛选
flutter test --update-goldens                 # 更新 golden 基准图
flutter test integration_test/                # 跑端到端测试（需模拟器/真机）
dart run build_runner build --delete-conflicting-outputs   # 重跑代码生成
flutter gen-l10n                # 重新生成国际化代码（改 .arb 后）
```

多环境运行/打包（详见 `lib/core/config/app_env.dart`）：

```bash
flutter run --dart-define=FLAVOR=staging
flutter build apk --dart-define=FLAVOR=prod
```

> ⚠️ 国内网络：命令行原生构建建议绕开代理，`env -u HTTP_PROXY -u HTTPS_PROXY flutter build ...`。
> iOS 模拟器 release 构建有 lipo 坑，调试用 `flutter run`。

## 架构

**feature-first 分层**：

```
lib/
  main.dart            # 极薄入口：runApp(ProviderScope(child: WanShopApp()))
  app/
    app.dart           #   WanShopApp：MaterialApp.router、主题、i18n delegate
    main_scaffold.dart #   MainScaffold：底部 4-Tab 外壳（ConsumerWidget，画购物车角标）
    router/app_router.dart  #   go_router：StatefulShellRoute + redirect 登录门禁
  core/                # 跨 feature 通用代码
    config/            #   AppEnv：--dart-define 多环境配置
    error/             #   AppException：sealed class 异常层级
    network/           #   DioClient + AuthInterceptor + LoggingInterceptor
    storage/           #   AuthStorage：token（flutter_secure_storage）
    widgets/           #   ErrorView 等共享组件
  features/<name>/     # 8 个业务模块：auth cart categories favorites orders products profile search
    data/ domain/ presentation/   # feature 内再分三层
                                  # presentation/providers/ 放该模块的 Riverpod provider
  l10n/                # .arb 翻译源 + gen-l10n 生成物（均入库）
```

关键约定：

- **`main.dart` 保持极薄**——只 `runApp`。装配全在 `app/app.dart`。
- **feature 之间不互相 import**。跨模块共享的东西上提到 `core/`。
- **导航状态归 go_router 管**：`MainScaffold` 不持有 `_currentIndex`，由 `StatefulShellRoute.indexedStack` 提供 `navigationShell`（4 个 Tab 各自保留导航栈与滚动位置）。
- **页面优先 `StatelessWidget` / `ConsumerWidget`**，把可变状态下沉到子 Widget 或 provider。
- 列表/网格用 `CustomScrollView` + Sliver 组合，整页单一滚动容器。
- **收窄重建**（M13 立的规矩）：watch 派生出的最小值（如 `cartTotalCountProvider` 而非整包 `cartProvider`），必要处加 `RepaintBoundary`。

### 技术选型（已定，不要再问）

| 领域 | 选型 |
|---|---|
| 状态管理 | **Riverpod 3.x** + `riverpod_annotation` 代码生成（`@riverpod`） |
| 网络 | **dio** + 拦截器栈；数据源 **DummyJSON**（`https://dummyjson.com`，测试账号 `emilys` / `emilyspass`） |
| 路由 | **go_router**（`StatefulShellRoute.indexedStack` + `redirect` + `refreshListenable`） |
| 序列化 | **json_serializable**（不用 freezed） |
| 存储 | **shared_preferences**（购物车/收藏/订单/离线缓存，存 JSON 字符串）+ **flutter_secure_storage**（token） |
| 图片 | **cached_network_image** |
| 国际化 | **flutter_localizations + intl**，`.arb` → `flutter gen-l10n`，中英双语 |
| 测试 | **mocktail** + `ProviderContainer` 直测 provider + `matchesGoldenFile` + `integration_test` |

**明确没有用**：freezed、drift/sqflite、bloc、get_it、alchemist。不要引入这些库"改进"现有代码。

### 代码生成

`.g.dart` 生成物**入库**。改了带 `@JsonSerializable` 或 `@riverpod` 的文件后要重跑 `build_runner`。
`lib/l10n/app_localizations*.dart` 同理——改 `.arb` 后跑 `flutter gen-l10n`，生成物入库，**不要手改生成的文件**。

## 课程模块（M0–M13 全部完成 ✅）

课时讲义见 `docs/lessons/`（索引：`docs/lessons/README.md`），每篇含核心概念、新控件速查表（iOS 类比 + 坑）、代码地图、自测清单。

| 模块 | 主题 |
|---|---|
| M0 | 4-Tab 骨架 + feature-first 目录结构 |
| M1 | 首页静态 UI（搜索框/Banner/分类入口/商品网格） |
| M2 | Dart 进阶 + 数据建模（json_serializable codegen） |
| M3 | 网络层 dio + Repository + sealed 异常映射 |
| M4 | Riverpod + AsyncValue 三态 + 下拉刷新/上拉分页 |
| M5 | go_router + 商品详情页 |
| M6 | 分类 & 搜索（family / autoDispose / 防抖） |
| M7 | 购物车：全局状态 + 本地持久化 ⭐ |
| M8 | 登录鉴权：Form + secure storage + 拦截器 + redirect ⭐ |
| M9 | 收藏 + 我的 + 离线缓存兜底 |
| M10 | 下单结算（mock 闭环） |
| M11 | 测试：mocktail / golden / integration_test |
| M12 | 发布 + 平台集成：Flavor + i18n ⭐ |
| M13 | 性能与收尾：收窄重建 / RepaintBoundary / 图片限解码 / lint 收紧 |

## 相关文档

- **原理深挖**（面试向）：仓库根 `doc/` —— [Riverpod 实现原理](../doc/Riverpod实现原理.md)、[Flutter 测试体系](../doc/Flutter测试体系.md)、[Mocktail 使用指南](../doc/Mocktail使用指南.md)、[多环境打包](../doc/Flutter多环境打包配置.md)、[国际化](../doc/Flutter国际化.md)
- **状态管理专题**：`../state_lab/`（五版 MiniShop 横向对比）
- **原生交互专题**：`../native_lab/`（L0–L9，MethodChannel / Pigeon / PlatformView / add-to-app）

## Git 约定（重要）

- 仓库根是 `/Users/wenbo/Desktop/WBFlutter`（**不是** `wan_android/`）。提交时**只 `git add wan_android/`**，避免把其他子工程的改动一起带进来。
- 直接提交到 `main`（线性学习日志风格）。提交信息用**中文、按模块**组织（如 `M13 性能与收尾：…`）。
- 提交信息不带 AI 署名/Co-Authored-By。
