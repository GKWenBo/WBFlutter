# WanShop（wan_android）

> 一个用来**从 0→1 实战学 Flutter** 的电商 App。工程包名保留 `wan_android`，
> App 显示名为 **WanShop**。数据来自公开 API [DummyJSON](https://dummyjson.com)
> （测试账号 `emilys` / `emilyspass`）。
>
> 这是**教学项目**：代码不是为了最快交付，而是为了讲清楚。注释面向 iOS/SwiftUI 背景的读者，
> 大量用类比讲原理（`StatefulWidget` ≈ 带 `@State` 的 SwiftUI View、`MaterialApp` ≈
> AppDelegate+UIWindow、`NavigationBar` ≈ UITabBar…）。配套讲义见
> **[docs/lessons/](docs/lessons/README.md)**（M0–M13，每模块一篇）。

---

## 快速开始

```bash
flutter pub get                                        # 拉依赖
dart run build_runner build --delete-conflicting-outputs   # 代码生成（模型/Riverpod）
flutter run                                            # 跑到模拟器/真机（热重载默认开）

flutter analyze                                        # 静态检查（提交前必跑）
flutter test                                           # 全部单元/Widget/Golden 测试
flutter test integration_test/                         # 端到端测试（≈ XCUITest）
```

> 改了带 `@JsonSerializable` / `@riverpod` 注解的代码后要重新生成：
> `dart run build_runner build --delete-conflicting-outputs`（或 `watch` 常驻自动生成）。

多环境（Flavor，M12）：

```bash
flutter run --dart-define=FLAVOR=dev        # dev / staging / prod，右上角有环境水印
flutter build apk   --dart-define=FLAVOR=prod
flutter build ipa   --dart-define=FLAVOR=prod
```

---

## 技术选型

| 关注点 | 选型 | iOS 对照 |
|---|---|---|
| 状态管理 | **Riverpod** 3.x + `riverpod_annotation` 代码生成 | ViewModel / `@Published` + DI 容器 |
| 网络 | **dio**（拦截器：日志 + 自动带 token） | URLSession + 拦截层 |
| 数据源 | **DummyJSON** 公开 API | — |
| 路由 | **go_router**（`StatefulShellRoute` + `redirect` 鉴权） | Coordinator / 深链 |
| 序列化 | **json_serializable** + `build_runner` | Codable |
| 普通存储 | **shared_preferences**（购物车/收藏/缓存） | UserDefaults |
| 安全存储 | **flutter_secure_storage**（token） | Keychain |
| 图片 | `Image.network` + `cached_network_image` | SDWebImage/Kingfisher |
| 国际化 | `flutter_localizations` + `gen-l10n`（`.arb`） | String Catalog / NSLocalizedString |
| 测试 | `flutter_test` + `mocktail` + Golden + `integration_test` | XCTest / 快照 / XCUITest |

---

## 架构设计

### 分层理念：feature-first + 每 feature 内三层

按**业务**切目录（不按 pages/models/services 这种技术类型切）。一个功能相关的页面、模型、
数据源全部收在同一个 `features/<name>/` 下，改一个功能不用横跨多个顶层目录。

```
lib/
  main.dart                     极薄入口：只 runApp(ProviderScope(WanShopApp()))
  app/                          全局装配
    app.dart                    WanShopApp：MaterialApp.router + 主题 + 环境水印
    main_scaffold.dart          底部 4-Tab（≈ UITabBarController），画购物车角标
    router/app_router.dart      go_router 路由表 + redirect 鉴权 + refreshListenable
  core/                         跨 feature 通用代码（feature 之间互不 import，共享下沉到这里）
    config/app_env.dart         Flavor/环境配置（baseUrl、日志开关、水印）
    network/                    dio 单例 + LoggingInterceptor + AuthInterceptor
    storage/auth_storage.dart   Keychain 封装（被拦截器 + auth feature 共用，故放 core）
    error/failure.dart          sealed AppException（统一错误模型）
    widgets/                    通用组件（错误态等）
  l10n/                         gen-l10n 生成的本地化访问类 + .arb（M12）
  features/<name>/
    data/                       DTO/信封、datasource（调 dio）、本地存储、Repository
    domain/                     纯业务模型（entity）、计算属性
    presentation/               page（页面）、widgets（局部组件）、providers（≈ ViewModel）
```

各 feature：`products`（首页商品流 + 详情）、`categories`、`search`、`cart`、`auth`、
`favorites`、`orders`、`profile`。

### 关键约定

- **`main.dart` 保持极薄**：只负责启动，主题/路由/首页装配全在 `app/`——接 Riverpod、go_router 时改动点集中。
- **每个 Tab 页面来自各自 feature，彼此不 import**；`MainScaffold` 用 `IndexedStack` 让 4 页常驻、保留各自滚动位置。
- **页面优先 `StatelessWidget`**，把可变状态下沉封装到最小需要它的子 Widget（Banner 页码封在 `HomeBanner`、轮播状态封在 `_DetailGallery`）。
- 列表/网格用 `CustomScrollView` + Sliver，整页单一滚动容器；长列表一律 `.builder`。

### 数据流（自里向外单向）

```
DummyJSON ──dio──▶ Repository ──▶ Riverpod Notifier(AsyncValue: loading/data/error) ──ref.watch──▶ Widget
                       │                     │
                 统一 AppException      派生 provider（总件数/总价/是否已收藏，收窄重建）
                                             │
                        shared_preferences / secure storage（本地持久化 + 离线兜底）
```

### 状态管理约定（Riverpod）

- **三态渲染**：Notifier `build()` 返回 `Future`，自动包成 `AsyncValue`，页面 `.when(loading/error/data)`，不手写 `isLoading`。
- **DI**：Repository/Storage 都做成 provider，测试用 `overrideWith` 换 mock。
- **生命周期**：全局唯一、活满 App 的状态（购物车/收藏/登录态）用 `@Riverpod(keepAlive: true)`；临时/大参数空间（分类商品、搜索结果）用默认 `autoDispose` + `family`。
- **异步竞态**：依赖旧状态的 mutation（加购/改量/收藏）先 `await future` 再改，防迟到结果覆盖新值；整替换（登录/登出）不需要。
- **收窄重建**：总件数/总价等做成**派生 provider**，只在派生值 `==` 真变时通知（Tab 角标不被无关改动惊动）。详见 [M13](docs/lessons/M13-性能与收尾.md)。

### 网络与错误

- `core/network/dio_client.dart` 单例，挂 `AuthInterceptor`（`onRequest` 异步读 Keychain 自动拼 `Bearer`）+ `LoggingInterceptor`（按 Flavor 开关）。
- Repository 在边界把 `DioException` 翻译成 `sealed` 的 `AppException`（Network/Server/Parse/Unknown）——UI 层永远不 catch dio。

### 路由与鉴权

- go_router 集中式路由表做成 `routerProvider`（能在 `redirect` 里读登录态）。
- `StatefulShellRoute.indexedStack` 托管 4-Tab，每 Tab 独立导航栈；详情/登录/搜索是顶层路由（全屏盖 Tab 栏）。
- 鉴权：`_protectedPaths` + 统一 `redirect` 拦未登录；`refreshListenable` 把 Riverpod 登录态变化（如登出）转成一次 redirect 重跑。

---

## 课程进度（M0–M13，已全部完成）

| 阶段 | 模块 |
|---|---|
| 骨架/UI | M0 起步重构 · M1 首页静态 UI |
| 数据/网络 | M2 建模与 codegen · M3 dio 网络层 |
| 状态/路由 | M4 Riverpod 三态与分页 · M5 go_router 与详情页 |
| 业务闭环 | M6 分类搜索 · M7 购物车 ⭐ · M8 登录鉴权 ⭐ · M9 收藏/离线缓存 · M10 下单结算 |
| 工程化 | M11 测试 · M12 发布/i18n ⭐ · M13 性能与收尾 |

每模块对应一次 git 提交，`git show <提交>` 可看该课全部代码变更。

---

## 课时讲义

完整索引见 **[docs/lessons/README.md](docs/lessons/README.md)**。每篇结构统一：
**重点掌握 → 新控件速查表（iOS 类比 / 用法 / 坑）→ 代码地图 → 自测清单 → 练习**。

| 模块 | 讲义 |
|---|---|
| M0 起步重构 | [M0-起步重构.md](docs/lessons/M0-起步重构.md) |
| M1 首页静态 UI | [M1-首页静态UI.md](docs/lessons/M1-首页静态UI.md) |
| M2 数据建模与 codegen | [M2-数据建模与codegen.md](docs/lessons/M2-数据建模与codegen.md) |
| M3 网络层 dio | [M3-网络层dio.md](docs/lessons/M3-网络层dio.md) |
| M4 Riverpod 三态与分页 | [M4-Riverpod三态与分页.md](docs/lessons/M4-Riverpod三态与分页.md) |
| M5 go_router 与详情页 | [M5-go_router与详情页.md](docs/lessons/M5-go_router与详情页.md) |
| M6 分类与搜索 | [M6-分类与搜索.md](docs/lessons/M6-分类与搜索.md) |
| M7 购物车全局状态与持久化 ⭐ | [M7-购物车全局状态与持久化.md](docs/lessons/M7-购物车全局状态与持久化.md) |
| M8 登录与鉴权 ⭐ | [M8-登录与鉴权.md](docs/lessons/M8-登录与鉴权.md) |
| M9 收藏与离线缓存 | [M9-收藏与离线缓存.md](docs/lessons/M9-收藏与离线缓存.md) |
| M10 下单结算 | [M10-下单结算.md](docs/lessons/M10-下单结算.md) |
| M11 测试 | [M11-测试.md](docs/lessons/M11-测试.md) |
| M12 发布与平台集成 ⭐ | [M12-发布与平台集成.md](docs/lessons/M12-发布与平台集成.md) |
| M13 性能与收尾 | [M13-性能与收尾.md](docs/lessons/M13-性能与收尾.md) |
