# WBFlutter · Flutter 开发参考手册

> 一份**面向 iOS 开发者**的 Flutter / Dart 知识库 + 实战代码仓。
> 不只是目录索引：这里汇总了环境搭建、命令速查、概念对照、状态管理选型、工程化规范与排错清单，
> 配套三个可运行的教学工程和一套深度原理文档。
>
> **版本基线**：Flutter `3.44` / Dart `3.12.2`（本机 SDK 实测）｜平台：macOS（Apple Silicon）

---

## 目录

- [1. 这是什么](#1-这是什么)
- [2. 仓库地图](#2-仓库地图)
- [3. 快速开始](#3-快速开始)
  - [3.1 环境搭建（macOS）](#31-环境搭建macos)
  - [3.2 常用命令速查](#32-常用命令速查)
  - [3.3 国内镜像与代理](#33-国内镜像与代理)
- [4. 学习路线](#4-学习路线)
- [5. 核心速查](#5-核心速查)
  - [5.1 iOS ↔ Flutter 概念对照](#51-ios--flutter-概念对照)
  - [5.2 Widget 与布局速查](#52-widget-与布局速查)
  - [5.3 状态管理选型](#53-状态管理选型)
  - [5.4 网络 / 持久化 / 路由](#54-网络--持久化--路由)
  - [5.5 原生交互](#55-原生交互)
- [6. 工程化规范](#6-工程化规范)
  - [6.1 推荐工程结构](#61-推荐工程结构)
  - [6.2 代码生成](#62-代码生成)
  - [6.3 测试金字塔](#63-测试金字塔)
  - [6.4 多环境打包](#64-多环境打包)
  - [6.5 国际化](#65-国际化)
  - [6.6 性能优化清单](#66-性能优化清单)
- [7. 文档索引](#7-文档索引)
- [8. 常用依赖清单](#8-常用依赖清单)
- [9. 排错与 FAQ](#9-排错与-faq)
- [10. 维护约定](#10-维护约定)

---

## 1. 这是什么

一个**边学边沉淀**的 Flutter 学习仓库，目标读者是有 iOS（Swift / SwiftUI / UIKit）背景的开发者。
核心方法：**概念迁移**——把每个 Flutter 知识点映射到你已熟悉的 iOS 概念上，再补差异。

三条内容线是互补关系，建议按「主线 → 专题 → 原理」的顺序使用：

| 层次 | 内容 | 回答的问题 |
|---|---|---|
| **主线实战** | [`Project/wan_android`](Project/wan_android)（WanShop 电商 App，M0–M13 讲义） | 一个完整 App 怎么从 0 搭到上架 |
| **专题突破** | [`Project/state_lab`](Project/state_lab)（状态管理 S0–S6）、[`Project/native_lab`](Project/native_lab)（原生交互 L0–L9） | 某个难点怎么吃透 |
| **原理深挖** | [`doc/`](doc/README.md)（Provider / Riverpod 原理、测试体系、国际化、多环境打包） | 它**为什么**这样设计（面试向） |
| **语言与入门** | [`Dart/`](Dart)、[`教程/`](教程) | Dart 语法、视频教程配套代码 |

---

## 2. 仓库地图

```
WBFlutter/
├── Dart/                       # Dart 语言练习（含 Dart语言简介.md）
├── doc/                        # 深度原理文档（面试向，见 doc/README.md 索引）
│   ├── iOS转Flutter学习路线.md   # 8–10 周完整路线 + 速查对照表
│   ├── Provider实现原理.md
│   ├── Riverpod实现原理.md
│   ├── Flutter测试体系.md
│   ├── Mocktail使用指南.md
│   ├── Flutter国际化.md
│   └── Flutter多环境打包配置.md
├── Project/                    # 可运行的示例工程
│   ├── wan_android/            # WanShop 电商 App（主线，M0–M13）
│   ├── state_lab/              # 状态管理横向对比（setState/Provider/Bloc/GetX/Riverpod）
│   ├── native_lab/             # 原生交互（MethodChannel/EventChannel/Pigeon/PlatformView/add-to-app）
│   └── wb_bloc_counter/        # 最小 Bloc 计数器示例
├── 教程/                        # 第三方视频教程 / 电子书的配套资料与代码
│   ├── Flutter基础视频教程/
│   ├── Flutter3.x入门实战视频教程/
│   └── Flutter实战电子书/
├── .gitignore
├── LICENSE
└── README.md                   # 本文件
```

| 入口 | 什么时候打开 |
|---|---|
| [`doc/iOS转Flutter学习路线.md`](doc/iOS转Flutter学习路线.md) | 刚入门，想先看全局路线图 |
| [`Project/wan_android/README.md`](Project/wan_android/README.md) | 想直接跑一个完整 App |
| [`Project/native_lab/docs/lessons/README.md`](Project/native_lab/docs/lessons/README.md) | 要搞原生混编 / add-to-app / 插件 |
| [`doc/README.md`](doc/README.md) | 面试复习、想搞懂底层机制 |

---

## 3. 快速开始

### 3.1 环境搭建（macOS）

1. **下载 Flutter SDK**：<https://docs.flutter.dev/release/archive>，解压到 `~/development`
2. **配置环境变量**（追加到 `~/.zshenv` 末尾；用 bash 则写 `~/.bash_profile`）

   ```bash
   export PATH=$HOME/development/flutter/bin:$PATH
   ```

3. **体检并逐项修绿**

   ```bash
   flutter doctor -v
   ```

   iOS 侧一般你已有 Xcode，直接复用；Android 侧需装 Android Studio + Android SDK + 同意 licenses：

   ```bash
   flutter doctor --android-licenses
   ```

4. **编辑器插件**（VS Code）

   - [Flutter](https://marketplace.visualstudio.com/items?itemName=Dart-Code.flutter)
   - [Code Runner](https://marketplace.visualstudio.com/items?itemName=formulahendry.code-runner)
   - [Flutter Widget Snippets](https://marketplace.visualstudio.com/items?itemName=alexisvt.flutter-snippets)

5. **跑通第一个 App**

   ```bash
   flutter create my_app && cd my_app && flutter run
   ```

   运行后按 `r` 热重载、`R` 热重启、`q` 退出。

> 官方中文文档：<https://docs.flutter.cn/> ｜《Flutter 实战·第二版》：<https://book.flutterchina.club/>

### 3.2 常用命令速查

| 分类 | 命令 | 说明 |
|---|---|---|
| 环境 | `flutter doctor -v` | 检查环境（Xcode / Android SDK / CocoaPods …） |
| 环境 | `flutter --version` / `flutter upgrade` | 查版本 / 升级 SDK |
| 环境 | `flutter channel stable` | 切通道（stable / beta / dev / master） |
| 项目 | `flutter create <name>` | 新建项目（跨平台默认全平台） |
| 项目 | `flutter create --platforms=ios,android --org com.xxx <name>` | 指定平台与包名 |
| 依赖 | `flutter pub get` / `pub add <pkg>` / `pub upgrade --major-versions` | 拉依赖 / 加包 / 大版本升级 |
| 依赖 | `flutter pub outdated` / `flutter pub deps` | 查可升级 / 看依赖树 |
| 运行 | `flutter devices` / `flutter emulators` | 列出设备 / 模拟器 |
| 运行 | `flutter run` / `flutter run -d <deviceId>` | 跑起来（默认开热重载） |
| 运行 | `flutter run --profile` / `--release` | 性能分析用 profile，**别用 debug 测性能** |
| 清理 | `flutter clean` | 清 build 产物（玄学报错第一招） |
| 检查 | `flutter analyze` | 静态检查，提交前必跑，目标 0 issue |
| 测试 | `flutter test` | 单元 + Widget + Golden 测试 |
| 测试 | `flutter test integration_test/` | 端到端测试（≈ XCUITest） |
| 代码生成 | `dart run build_runner build --delete-conflicting-outputs` | json_serializable / riverpod_generator |
| 代码生成 | `dart run build_runner watch` | 监听模式，开发中常用 |
| 构建 | `flutter build apk` / `flutter build appbundle` | Android 包（上架用 appbundle） |
| 构建 | `flutter build ios` / `flutter build ipa` | iOS（上架用 ipa） |
| 构建 | `flutter build web` / `flutter build macos` | Web / 桌面端 |
| 国际化 | `flutter gen-l10n` | 由 `.arb` 生成本地化代码 |
| 调试 | `flutter logs` / `flutter screenshot` | 看日志 / 截图 |
| 性能 | `flutter run --profile` + `dart devtools` | DevTools 性能面板 |

**带编译期变量运行**（多环境常用）：

```bash
flutter run --dart-define=ENV=staging --dart-define=BASE_URL=https://staging.example.com
flutter build apk --flavor prod -t lib/main_prod.dart
```

### 3.3 国内镜像与代理

`pub get` 或 SDK 下载卡住时，临时或永久配置镜像（追加到 `~/.zshenv`）：

```bash
export PUB_HOSTED_URL=https://pub.flutter-io.cn
export FLUTTER_STORAGE_BASE_URL=https://storage.flutter-io.cn
```

---

## 4. 学习路线

完整版见 [`doc/iOS转Flutter学习路线.md`](doc/iOS转Flutter学习路线.md)（含每阶段产出与练习建议）。按每天 2–3 小时，约 **8–10 周**可达到上手公司项目的水平。

| 阶段 | 主题 | 耗时 | 对应本仓库资源 |
|---|---|---|---|
| 0 | 环境与工具链 | 1–2 天 | 本文档第 3 节 |
| 1 | Dart 语言（空安全 / 异步 / sealed class） | 4–6 天 | [`Dart/`](Dart) |
| 2 | Widget 与声明式 UI | 1 周 | [`教程/Flutter基础视频教程`](教程/Flutter基础视频教程) |
| 3 | 布局系统（Constraints 向下、尺寸向上） | 4–5 天 | 第 5.2 节 |
| 4 | 状态管理（Riverpod 为主）⭐ | 1.5 周 | [`Project/state_lab`](Project/state_lab) + `doc/` 原理两篇 |
| 5 | 异步、网络、数据持久化 | 1 周 | wan_android 的 M2 / M3 / M9 |
| 6 | 路由导航（go_router） | 2–3 天 | wan_android 的 M5 |
| 7 | 平台集成（你的强项）⭐ | 3–5 天 | [`Project/native_lab`](Project/native_lab) L0–L9 |
| 8 | 工程化、测试、发布 | 1 周 | 第 6 节 + `doc/` 工程化两篇 |
| — | 综合实战 | 2–3 周 | [`Project/wan_android`](Project/wan_android) M0–M13 |

---

## 5. 核心速查

### 5.1 iOS ↔ Flutter 概念对照

| iOS | Flutter | 备注 |
|---|---|---|
| `UIView` / SwiftUI `View` | `Widget` | 一切皆 Widget（布局、间距、手势也是） |
| `UIViewController` | `StatefulWidget` + 页面 | 没有强制 VC 概念 |
| SwiftUI `@State` | `State` + `setState()` | 局部状态 |
| `viewDidLoad` / `deinit` | `initState()` / `dispose()` | 初始化 / 释放 |
| `UILabel` / `UIImageView` / `UIButton` / `UITextField` | `Text` / `Image` / `ElevatedButton` / `TextField` | |
| `UITableView` / `UICollectionView` | `ListView.builder` / `GridView.builder` | builder ≈ cell 复用 |
| `HStack` / `VStack` / `ZStack` | `Row` / `Column` / `Stack` | |
| Auto Layout 约束 | Constraints 向下传、尺寸向上传、父级定位 | 理念不同，必须专门理解 |
| `UIStackView` 等分 / `Spacer` | `Expanded` / `Flexible` / `Spacer` | |
| Coordinator / 路由表 | `go_router` | 官方推荐声明式路由 |
| Combine `Publisher` / RxSwift | `Stream` | 多次异步事件流 |
| `URLSession` | `dio` | |
| `Codable` | `json_serializable` + `build_runner` | Dart 无内建 Codable |
| `UserDefaults` / Keychain / Core Data | `shared_preferences` / `flutter_secure_storage` / `drift` | |
| `DispatchQueue` | 事件循环 + `Isolate` | Dart 单线程，重活丢 `Isolate` |
| CocoaPods / `Podfile` | pub / `pubspec.yaml` | |
| XCTest / XCUITest | `flutter_test` / `integration_test` | |
| —（你就是原生） | `MethodChannel` / `EventChannel` | 平台通道 |

> 完整速查表（含 MVVM、DI、NotificationCenter 对照）见 `doc/iOS转Flutter学习路线.md` 第十三节。

### 5.2 Widget 与布局速查

| 类别 | Widget | 用途 |
|---|---|---|
| 基础 | `Text` `Image` `Icon` `ElevatedButton` `TextButton` `IconButton` `TextField` | 基础展示与交互 |
| 容器 | `Container` `Padding` `SizedBox` `Center` `Align` `DecoratedBox` `ClipRRect` `Card` | 尺寸 / 边距 / 装饰 / 裁剪 |
| 线性布局 | `Row` `Column` `Flex` `Expanded` `Flexible` `Spacer` | 主轴 / 交叉轴排布 |
| 层叠 | `Stack` `Positioned` `IndexedStack` | 绝对定位与叠加 |
| 滚动 | `SingleChildScrollView` `ListView` `GridView` `CustomScrollView` `SliverList` `SliverAppBar` | 列表与懒加载 |
| 适配 | `SafeArea` `MediaQuery` `LayoutBuilder` `FittedBox` `AspectRatio` `Wrap` `FlexibleSpaceBar` | 刘海屏 / 响应式 / 流式换行 |
| 交互 | `GestureDetector` `InkWell` `Dismissible` `RefreshIndicator` `Draggable` | 手势与滑动行为 |
| 导航 | `Navigator` `BottomNavigationBar` `TabBar` `Drawer` `AppBar` `Scaffold` | 页面骨架 |
| 动画 | `AnimatedContainer` `AnimatedOpacity` `Hero` `AnimatedBuilder` `AnimatedSwitcher` | 隐式动画 / 转场 |
| 状态 | `FutureBuilder` `StreamBuilder` `ValueListenableBuilder` | 内建响应式刷新 |

**布局铁律**：`Constraints go down, sizes go up, parent sets position`。
搞懂这一句能消掉 90% 的 `RenderFlex overflowed` 报错——溢出本质是子级想要的空间超过父级给的约束。

**响应式断点**（常用经验值）：

```dart
final width = MediaQuery.sizeOf(context).width;
if (width < 650) { /* 手机 */ }
else if (width < 1100) { /* 平板 */ }
else { /* 桌面 */ }
```

### 5.3 状态管理选型

| 方案 | 定位 | 建议 |
|---|---|---|
| `setState` | 内建，widget 内部局部状态 | 每个项目都用，但**不能当架构** |
| **Riverpod 3.x** | 新项目首选 / 社区主流 | 编译期安全、不依赖 `BuildContext`、自动释放、异步支持好 |
| Bloc / Cubit | 大团队 / 强监管行业（金融、医疗） | 事件→状态单向流、可审计、样板代码多 |
| Provider | Riverpod 的前身 | 仅维护老项目 |
| GetX | 上手快但架构问题多 | **新项目建议避免** |

推荐路径：`setState` 理解重建 → **Riverpod** 串起来状态 / 网络 / 缓存 → 有余力看 Bloc。

```dart
// Riverpod 3.x：注解 + 代码生成（本仓库 wan_android 的写法）
@riverpod
class ProductList extends _$ProductList {
  @override
  Future<List<Product>> build() => ref.watch(productRepoProvider).fetchPage(0);

  Future<void> refresh() async => state = AsyncData(await ref.watch(productRepoProvider).fetchPage(0));
}

// 消费：用 select 只订阅需要的字段，避免整树重建
final count = ref.watch(cartProvider.select((s) => s.items.length));
```

### 5.4 网络 / 持久化 / 路由

**三态建模**（Dart 3 `sealed class` + 模式匹配，对应 Swift 带关联值 enum）：

```dart
sealed class LoadState<T> {}
class Loading<T> extends LoadState<T> {}
class Success<T> extends LoadState<T> { final T data; Success(this.data); }
class Failure<T> extends LoadState<T> { final String message; Failure(this.message); }

Widget buildBody(LoadState<List<Product>> s) => switch (s) {
  Loading()   => const Center(child: CircularProgressIndicator()),
  Success(:final data) => ProductGrid(data),
  Failure(:final message) => ErrorView(message),
};
```

**dio 单例 + 拦截器**（认证、日志、重试）：

```dart
final dio = Dio(BaseOptions(baseUrl: baseUrl, connectTimeout: const Duration(seconds: 10)))
  ..interceptors.add(AuthInterceptor())
  ..interceptors.add(LogInterceptor(responseBody: false));
```

**go_router 声明式路由**：

```dart
final router = GoRouter(
  routes: [
    GoRoute(path: '/', builder: (_, __) => const HomePage(),
      routes: [GoRoute(path: 'detail/:id', builder: (_, s) => DetailPage(id: s.pathParameters['id']!))]),
  ],
  redirect: (context, state) => isLoggedIn ? null : '/login',   // 登录拦截
);
```

**持久化选型**：简单键值 `shared_preferences`；敏感信息 `flutter_secure_storage`；结构化数据 `drift`（类型安全 ORM）或 `isar`。

### 5.5 原生交互

| 需求 | 方案 |
|---|---|
| Dart 调原生（设备信息、SDK） | `MethodChannel` |
| 原生持续推流（传感器、网络状态） | `EventChannel` |
| 类型安全、免手写字符串协议 | `Pigeon`（代码生成） |
| Flutter 里嵌原生视图（地图、相机） | `PlatformView` |
| 原生 App 嵌 Flutter 页面 | add-to-app |
| 封装复用能力 | 写 Flutter Plugin（platform interface + 双端实现） |

```dart
// Dart 侧
const _ch = MethodChannel('com.wb/device');
final info = await _ch.invokeMethod<Map<Object?, Object?>>('getDeviceInfo');
```

```swift
// iOS 侧（AppDelegate 或插件注册处）
let channel = FlutterMethodChannel(name: "com.wb/device", binaryMessenger: registrar.messenger())
channel.setMethodCallHandler { call, result in
    switch call.method {
    case "getDeviceInfo": result(["model": UIDevice.current.model, "system": UIDevice.current.systemVersion])
    default: result(FlutterMethodNotImplemented)
    }
}
```

> ⭐ 这是 iOS 背景最值钱的地方：别人卡在写原生侧，你能直接写 Swift/OC。
> 完整十课见 [`Project/native_lab/docs/lessons/README.md`](Project/native_lab/docs/lessons/README.md)。

---

## 6. 工程化规范

### 6.1 推荐工程结构

按 feature 分层的 Clean Architecture（本仓库 `wan_android` 采用）：

```
lib/
├── main.dart                 # 入口（可拆 main_dev/main_staging/main_prod）
├── app/                      # 应用级：MaterialApp、router、theme
│   └── router/
├── core/                     # 跨模块基建
│   ├── config/               # 环境配置（--dart-define 读入）
│   ├── network/              # dio 单例、拦截器
│   ├── storage/              # 本地缓存
│   ├── error/                # 统一异常与 Result 类型
│   └── widgets/              # 通用 UI 组件
├── features/<module>/        # 每个业务模块自洽
│   ├── data/                 # 数据源、DTO、Repository 实现
│   ├── domain/               # 实体、Repository 抽象
│   └── presentation/
│       ├── providers/        # Riverpod Notifier
│       └── widgets/          # 页面与组件
└── l10n/                     # .arb 翻译源
```

约定：模块之间不横向依赖 `presentation`，跨模块走 `domain` 或路由；新增模块先建目录再写码。

### 6.2 代码生成

用到 `json_serializable`、`riverpod_generator`、`Pigeon` 时，改完源码必须重跑：

```bash
dart run build_runner build --delete-conflicting-outputs   # 一次生成
dart run build_runner watch                                # 开发中监听
```

生成物（`*.g.dart` / `*.freezed.dart`）建议纳入版本控制，避免 CI 环境缺少生成步骤。

### 6.3 测试金字塔

| 层级 | 命令 | 覆盖什么 |
|---|---|---|
| 单元测试 | `flutter test` | 纯 Dart 逻辑、Repository、Notifier |
| Widget 测试 | `flutter test` | 单组件渲染与交互（快，最常用） |
| Golden 测试 | `flutter test --update-goldens` | UI 视觉回归 |
| 集成测试 | `flutter test integration_test/` | 关键端到端流程 |

```bash
flutter analyze          # 提交前必跑，目标 0 issue
flutter test             # 关键路径必须有回归保护
```

Mock 用 [`mocktail`](doc/Mocktail使用指南.md)（零代码生成），Bloc 额外用 `bloc_test`。
详细策略见 [`doc/Flutter测试体系.md`](doc/Flutter测试体系.md)。

### 6.4 多环境打包

- 只切 `baseUrl` / 开关 → 用 `--dart-define`（最轻）
- 需要不同包名、图标、签名、GoogleService-Info → 用 `--flavor`（需配置双端 Scheme / productFlavors）

```bash
flutter run   --dart-define=ENV=staging --flavor staging -t lib/main_staging.dart
flutter build ipa --flavor prod -t lib/main_prod.dart
```

对应 iOS 的 Scheme/Configuration、Android 的 productFlavors。
完整配置见 [`doc/Flutter多环境打包配置.md`](doc/Flutter多环境打包配置.md)。

### 6.5 国际化

流程：`.arb` 源文件 → `flutter gen-l10n` → `AppLocalizations.of(context).xxx`。

```yaml
# l10n.yaml
arb-dir: lib/l10n
template-arb-file: app_en.arb
output-localization-file: app_localizations.dart
output-class: AppLocalizations
nullable-getter: false      # of(context) 返回非空，少写一堆 !
```

详见 [`doc/Flutter国际化.md`](doc/Flutter国际化.md)。

### 6.6 性能优化清单

目标：稳定 60fps，单帧 < 16ms。

- [ ] 能用 `const` 构造函数就用（widget 重建时被复用）
- [ ] 列表一律 `ListView.builder` / `SliverList`，不用一次性 `ListView(children: [...])`
- [ ] `ref.watch(p.select((s) => s.field))` 精确订阅，避免整树重建
- [ ] 大组件子树加 `RepaintBoundary` 隔离重绘
- [ ] CPU 密集（大 JSON 解析、图片处理）丢 `Isolate.run()`，别堵 UI isolate
- [ ] 网络图片用 `cached_network_image`，并指定 `memCacheWidth` 限制解码尺寸
- [ ] 少用 `Opacity` / `Clip` 嵌套（触发 `saveLayer`，代价高）
- [ ] 拆大 `build` 方法为小 widget（重绘范围更小）
- [ ] **永远用 `--profile` 模式测性能**，debug 模式数据没有意义
- [ ] 首帧着色器卡顿可做 SkSL 预热（`flutter run --cache-sksl --purge-persistent-cache`）

---

## 7. 文档索引

**深度原理（`doc/`）** —— 回答「为什么这么设计」，面试向：

| 文档 | 一句话 |
|---|---|
| [`iOS转Flutter学习路线.md`](doc/iOS转Flutter学习路线.md) | 8–10 周路线 + 速查对照表 + 选型建议 |
| [`Provider实现原理.md`](doc/Provider实现原理.md) | InheritedWidget 语法糖 + ChangeNotifier 监听桥接 |
| [`Riverpod实现原理.md`](doc/Riverpod实现原理.md) | 依赖图搬出 Widget 树：DAG 建图、惰性传播、autoDispose |
| [`Flutter测试体系.md`](doc/Flutter测试体系.md) | 五层测试全景 + CI 策略与覆盖率门槛 |
| [`Mocktail使用指南.md`](doc/Mocktail使用指南.md) | 零代码生成 Mock 的 API 与陷阱 |
| [`Flutter国际化.md`](doc/Flutter国际化.md) | `.arb` → gen-l10n → `l10n.xxx` 全流程 |
| [`Flutter多环境打包配置.md`](doc/Flutter多环境打包配置.md) | `--flavor` + `--dart-define` 双端配置 |

**课程讲义（跟着做，讲 API 与工程用法）**：

| 课程 | 范围 | 入口 |
|---|---|---|
| WanShop 综合实战 | M0–M13 | [`Project/wan_android/docs/lessons/`](Project/wan_android/docs/lessons/) |
| 状态管理专题 | S0–S6 + `docs/tech/` | [`Project/state_lab/docs/lessons/`](Project/state_lab/docs/lessons/) |
| 原生交互专题 | L0–L9 + 自测答案 + 面试总纲 | [`Project/native_lab/docs/lessons/`](Project/native_lab/docs/lessons/) |

---

## 8. 常用依赖清单

来源于本仓库 `pubspec.yaml`，均为当前实际使用版本，可直接复用：

| 用途 | 包 | 版本 | 用于 |
|---|---|---|---|
| 网络 | `dio` | `^5.9.2` | wan_android / state_lab |
| 状态管理 | `flutter_riverpod` + `riverpod_annotation` + `riverpod_generator` | `^3.3.2` / `^4.0.3` / `^4.0.4` | wan_android |
| 状态管理（对比） | `provider` / `flutter_bloc`+`equatable` / `get` | `^6.1.5+1` / `^9.1.1` / `^4.7.3` | state_lab 横向对比 |
| 路由 | `go_router` | `^17.3.0` | wan_android |
| JSON | `json_annotation` + `json_serializable` + `build_runner` | `^4.12.0` / `^6.14.0` / `^2.15.0` | 全部 |
| 存储 | `shared_preferences` / `flutter_secure_storage` | `^2.5.5` / `^10.3.1` | wan_android |
| 图片 | `cached_network_image` | `^3.4.1` | wan_android |
| 测试 | `mocktail` / `bloc_test` / `integration_test` | `^1.0.5` / `^10.0.0` / SDK 自带 | 全部 |
| 国际化 | `flutter_localizations` + `intl` | SDK 自带 / `any` | wan_android |
| Lint | `flutter_lints` | `^6.0.0` | 全部 |

选包参考：<https://pub.dev>（看 popularity / pub points / 最近更新时间）。

---

## 9. 排错与 FAQ

| 症状 | 原因 / 处理 |
|---|---|
| `RenderFlex overflowed by XX pixels` | 子级要的空间超过父约束。用 `Expanded`/`Flexible` 分摊，或外层包 `SingleChildScrollView` |
| `pub get` 卡住 / 超时 | 配国内镜像（见 3.3）；或检查代理环境变量 |
| `flutter doctor` Android 项报 licenses 未同意 | `flutter doctor --android-licenses` 全选 y |
| CocoaPods 版本不匹配 | `sudo gem install cocoapods`（或用 brew 安装的 ruby 环境） |
| 升级 Xcode 后 iOS 构建失败 | `flutter clean` → `rm -rf ios/Pods ios/Podfile.lock` → `pod install` → 重新 build |
| `build_runner` 报冲突 | 加 `--delete-conflicting-outputs`；仍失败先 `flutter clean` |
| 改了模型但运行时没生效 | 忘了跑代码生成（见 6.2） |
| `flutter analyze` 一堆 lint | 先在 `analysis_options.yaml` 统一规则，再逐条修，不要全局 `@ignore` |
| 热重载不生效 | 改的是 `main()` / 全局变量 / 初始化逻辑 → 用 `R` 热重启 |
| 模拟器上很卡 | 用 `--profile` 或 `--release` 复测，debug 模式本身慢 |
| 真机 iOS 签名失败 | 在 Xcode 里先 `Open iOS module` 配好 Signing & Capabilities，再回命令行 build |

**万能三连**：`flutter clean` → `flutter pub get` → 重启 IDE / 重新 build。

---

## 10. 维护约定

- 文档命名：**中文、无空格**；新增文档请同步更新 `doc/README.md` 索引与本文件第 7 节。
- 代码块中标注为「源码」的片段多为**示意性伪代码**，用于讲机制，字段名与真实包实现未必一致。
- ⚠️ = 高频陷阱；⭐ = 面试重点或关键约束。
- 提交前：`flutter analyze` 通过 + 关键路径 `flutter test` 通过。
- 版本相关 API（如 Riverpod 3.x、go_router 17.x）以官方文档为准，本仓库记录的是当时的写法。

---

## License

见 [LICENSE](LICENSE)。
