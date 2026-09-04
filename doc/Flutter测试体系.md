# Flutter 测试体系全景图

> **适用版本**：Flutter 3.x / Riverpod 3.x
> **技术栈前提**：Riverpod 3.x + Dio + drift + go_router
> **配套阅读**：[Mocktail 使用指南](Mocktail使用指南.md)（第六节的展开）、[Riverpod 实现原理](Riverpod实现原理.md)（第七节的原理依据）
> **工程实战**：[WanShop M11 · 测试](../wan_android/docs/lessons/M11-测试.md)

按"金字塔"从下到上梳理。当前主流实践与较早的教程（golden_toolkit、mockito）已有代际差异，先说结论再展开。

## 一、测试金字塔 & iOS 对照

| 层级            | Flutter 工具                    | 占比参考       | iOS 对照                                 | 运行速度              |
| --------------- | ------------------------------- | -------------- | ---------------------------------------- | --------------------- |
| 单元测试        | `flutter_test` (纯 Dart)        | ~60%           | `XCTest` (XCTestCase)                    | 毫秒级                |
| Widget 测试     | `flutter_test` (`WidgetTester`) | ~25%           | 无直接对应；接近 SwiftUI `ViewInspector` | 毫秒~秒级             |
| Golden 测试     | `alchemist`                     | 归入 Widget 层 | pointfree `SnapshotTesting`              | 秒级                  |
| 集成测试        | `integration_test`              | ~10%           | `XCUITest`                               | 分钟级，需真机/模拟器 |
| E2E（原生交互） | `patrol`                        | ~5%            | `XCUITest` + Springboard 操作            | 分钟级                |

常见的经验配比是 4 层金字塔：60% 单元测试 / 25% Widget 测试 / 10% 集成测试 / 5% E2E。

> ⚠️ 这个比例是**用例数量**占比，不是时间占比——集成测试单条耗时可能是单元测试的百倍。也不是硬指标，具体按项目的风险分布调整。

------

## 二、单元测试（Unit Test）

对应 iOS 的 `XCTestCase`，测纯逻辑，不碰 Flutter 运行时（不需要 `WidgetsBinding`）。

```dart
// 测试你的 Dio 拦截器里的 token 刷新逻辑
test('并发 401 时只触发一次 refresh，其余请求等待 Completer', () async {
  final authInterceptor = AuthInterceptor(tokenRefresher: mockRefresher);
  
  // 模拟 3 个并发请求同时收到 401
  final results = await Future.wait([
    authInterceptor.onError(unauthorizedError1),
    authInterceptor.onError(unauthorizedError2),
    authInterceptor.onError(unauthorizedError3),
  ]);
  
  verify(() => mockRefresher.refresh()).called(1); // 只调用一次
});
```

这一层最适合覆盖 WanShop 里的 **sealed exception 层级、`Result<T>` 类型、重试退避算法**——纯逻辑、无 I/O、跑得飞快，应该占测试套件的大头。

------

## 三、Widget 测试

测单个 Widget 在隔离环境中的渲染与交互，不需要真机。核心 API 是 `WidgetTester`：

```dart
testWidgets('登录按钮在表单无效时禁用', (tester) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [authProvider.overrideWith(() => FakeAuthNotifier())],
      child: const MaterialApp(home: LoginScreen()),
    ),
  );

  await tester.enterText(find.byKey(const Key('email_field')), 'invalid');
  await tester.pump(); // 触发一帧重建，对应 setState 后的同步刷新

  final button = tester.widget<ElevatedButton>(find.byKey(const Key('submit_btn')));
  expect(button.onPressed, isNull); // 禁用态
});
```

⚠️ **`pump()` vs `pumpAndSettle()`**：`pump()` 只推进一帧；`pumpAndSettle()` 会一直 pump 直到没有 pending 的 frame（动画、Future）。对有动画或异步操作的 Widget，用 `pumpAndSettle()`，否则断言会踩在动画中间态上——这是新手最常见的 flaky test 来源。

------

## 四、Golden 测试（视觉回归）

对应 iOS 生态里 pointfree 的 `SnapshotTesting`，把 Widget 渲染成图片和基准图逐像素比对。

**用在哪：** Golden 测试有价值，但应限制在设计系统的基础组件上，而不是整屏截图。针对 `PrimaryButton`、`ProductCard` 这类原子组件的 Golden 测试是可持续的；整个 `CheckoutScreen` 三种状态的截图测试则是维护负担——业务页面改动频繁，基准图会天天需要更新，最后没人认真看 diff。

**用什么：** 工具选择上有一个明显的代际更替——`golden_toolkit` 已停止维护，社区主流迁移到 **alchemist**（Betterment 与 Very Good Ventures 合作开发），提供分组场景、跨平台适配等能力。较老的教程很多还在讲 golden_toolkit，需要留意这个替换。

```dart
goldenTest(
  'ProductCard 在浅色/深色主题下的渲染',
  fileName: 'product_card',
  builder: () => GoldenTestGroup(
    children: [
      GoldenTestScenario(name: 'light', child: ProductCard(product: mockProduct)),
      GoldenTestScenario(name: 'dark', child: Theme(data: ThemeData.dark(), child: ProductCard(product: mockProduct))),
    ],
  ),
);
```

⚠️ **常见坑**：不同机器渲染字体/DPR 不一致导致 CI 上误报。生产做法是 CI 环境固定用 font-only 渲染模式、本地用 platform 模式分开跑，并且把生成的基准图打包进仓库、锁定字体资源。

------

## 五、集成测试 & E2E（Patrol）

flutter_driver 已被废弃，官方现在推荐使用 integration_test 包，跑在真机/模拟器上，测试完整用户流程。

但 `integration_test` 有个天生短板：它测不到**原生层面的交互**——系统权限弹窗、Face ID、支付面板这些不属于 Flutter widget 树的东西。

这时候要用 **Patrol**。它在 `integration_test` 之上加了一层原生自动化桥接，专门处理权限弹窗、生物识别、支付面板等原生 OS 交互。想留在 Dart 生态内写这类用例，目前它基本是唯一成熟的选择（另一条路是直接写 XCUITest / Espresso，但要跳出 Dart）。

```dart
patrolTest('登录后触发 Face ID 授权', ($) async {
  await $.pumpWidgetAndSettle(const MyApp());
  await $.tap($(#loginButton));
  
  // 这一步是纯 Flutter Widget 测试做不到的：操作系统原生弹窗
  await $.native.grantPermissionWhenInUse();
});
```

对 **add-to-app 场景**尤其相关：Flutter 页面内嵌在 iOS `UINavigationController` 里时，纯 `integration_test` 覆盖不到宿主 App 侧的原生跳转，Patrol 能桥接过去验证跨端导航。参见 [NativeLab L8/L9 · add-to-app](../native_lab/docs/lessons/README.md)。

------

## 六、Mock 工具：mocktail vs mockito

mockito 曾长期是默认选择，新项目现在普遍转向 mocktail：表达能力相同，但不需要代码生成、不需要 `build_runner`、不需要注解，测试文件写完就能直接跑。

> 原理层面的差异（`noSuchMethod` 动态派发 vs 代码生成）和完整 API 用法，见 [Mocktail 使用指南](Mocktail使用指南.md)。

|                 | mockito                            | mocktail                                            |
| --------------- | ---------------------------------- | --------------------------------------------------- |
| 代码生成        | 需要 `build_runner`                | 不需要                                              |
| Null Safety     | 后补支持                           | 原生设计                                            |
| 语法            | `@GenerateMocks([Dio])` + 生成文件 | 直接 `class MockDio extends Mock implements Dio {}` |
| 新项目推荐      | ❌ 遗留项目维护用                   | ✅                                                   |

```dart
class MockDio extends Mock implements Dio {}

void main() {
  late MockDio mockDio;
  setUp(() => mockDio = MockDio());

  test('401 触发 token 刷新并重试原请求', () async {
    when(() => mockDio.get(any())).thenThrow(
      DioException(requestOptions: RequestOptions(path: '/api'), response: Response(statusCode: 401, requestOptions: RequestOptions(path: '/api'))),
    );
    // ...
  });
}
```

⚠️ 对已经写好的 Dio 拦截器栈，直接 mock `Dio` 类做单元测试即可；如果想测"真实网络层但不发真请求"，可以用 `http_mock_adapter` 挂到 `Dio` 的 `HttpClientAdapter` 上，两者场景不同：mock `Dio` 测拦截器逻辑本身，mock adapter 测端到端的请求/响应契约。

------

## 七、状态管理专项测试 ⭐

### Riverpod：`ProviderContainer`，不需要 Widget 树

Riverpod 的依赖图[独立于 Widget 树存在](Riverpod实现原理.md#四providerscope图和-widget-树是怎么接起来的)，所以测试 Provider 逻辑根本不需要 `pumpWidget`：

```dart
test('AsyncNotifier 加载失败时进入 AsyncError', () async {
  when(() => mockDio.get(any())).thenThrow(DioException(...));

  final container = ProviderContainer(
    overrides: [dioProvider.overrideWithValue(mockDio)],
  );
  addTearDown(container.dispose); // ⚠️ 必须清理，否则跨测试状态泄漏

  // 等待 future 完成；预期抛错，所以断言异常而不是吞掉它
  await expectLater(
    container.read(userProfileProvider.future),
    throwsA(isA<DioException>()),
  );

  // future 结算后，provider 的同步状态才落到 AsyncError
  expect(container.read(userProfileProvider), isA<AsyncError>());
});
```

> ⚠️ **Riverpod 3.x 注意**：provider build 抛异常后**默认会指数退避重试**。测这类失败路径时，如果断言的是"只请求了一次"，需要在 provider 上关掉 `retry`，否则 `verify(...).called(1)` 会随重试时机变得 flaky。

### Bloc：`bloc_test` 包

测试 Bloc 确保事件触发正确的状态转换，涵盖成功、失败与异步场景：

```dart
blocTest<AuthBloc, AuthState>(
  'emits [Loading, Authenticated] on LoginRequested 成功',
  build: () => AuthBloc(authRepository: mockRepo),
  act: (bloc) => bloc.add(LoginRequested(email: 'a@b.com', password: '123')),
  expect: () => [AuthLoading(), AuthAuthenticated(user: mockUser)],
);
```

两者对比一目了然：Riverpod 测试直接操作 `ProviderContainer`，Bloc 测试用 `blocTest` 的 build/act/expect DSL——面试被问到"如何测试你选的状态管理方案"时，这个差异本身就是一个考点（在于 Riverpod 状态图独立于对象生命周期，Bloc 需要显式构造实例）。

------

## 八、⚠️ 高频陷阱清单

1. **Golden 测试字体差异**：本地 macOS 和 CI Linux 渲染字体不同，需固定测试字体/DPR
2. **`pump()` 漏用**：异步 setState 后忘记 pump，断言读到旧状态
3. **`ProviderContainer` 忘记 dispose**：跨测试用例状态泄漏，导致"单独跑通过、批量跑失败"的诡异现象
4. **对 drift 用真实数据库**：应该用 `NativeDatabase.memory()` 起内存库做单元测试，不要连生产 schema
5. **集成测试里 mock 外部依赖不彻底**：依赖外部服务或设备状态的集成测试容易 flaky，应 mock 外部依赖或使用稳定状态的测试环境

------

## 九、企业级 CI 集成参考

按层级设置不同覆盖率门槛而非单一项目级数字：业务逻辑（models/services/repositories）常见目标 80%+，展示层（widgets/screens）60-70% 较合理，生成代码/mock/路由表则完全排除。

CI 拆分策略：单元测试 + Widget 测试用 Linux runner 跑（快、便宜），只有真正需要 iOS 模拟器的集成测试才上 macOS runner——因为 macOS 分钟消耗是 Linux 的 10 倍，这点在控制 CI 成本上很实际。

Golden 更新走 PR 门禁模式：PR 分支上 CI 只报告 diff、不自动更新基准图，合并到 main 后才自动更新提交，防止意外的截图漂移。
