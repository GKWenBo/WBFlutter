# Mocktail 使用指南 —— 面向 iOS 工程师的 Flutter 测试 Mock 框架

## 1. 定位:概念迁移到 iOS

| Flutter/Dart | 作用 | iOS 对应概念 |
|---|---|---|
| `mocktail` | 零代码生成的 Mock 库 | 手写 Fake 类(遵循 protocol) |
| `mockito`(旧) | 反射/代码生成 Mock 库 | Cuckoo / Mockingbird(代码生成) |
| `Mock` 基类 + `noSuchMethod` | 动态拦截所有方法调用 | OCMock 的 `-forwardInvocation:`(消息转发) |
| `when()` / `verify()` | 打桩 / 验证调用 | OCMock 的 `stub`/`verify`,或手写 spy 变量 |

**关键差异点(面试高频):** Java 的 Mockito 靠 JVM 反射在运行时动态生成代理类,这一套在 Dart AOT 编译 + tree-shaking 的环境下行不通,所以早期 Dart 版 `mockito` 也不得不走 `build_runner` 代码生成路线(`@GenerateMocks`)。Mocktail 换了个思路:利用 Dart 语言本身保留的 `noSuchMethod` 动态派发能力,让 `Mock` 基类拦截所有未实现的方法调用——这个机制在概念上更接近 Objective-C 的动态消息转发(OCMock 能工作的底层原理),而不是 Swift 静态类型系统下那种"写死的" protocol mock。这也是为什么 Swift 原生没有类似 mockito 的框架,而 Dart 反而可以做到零代码生成。

---

## 2. 核心 API 五件套

### 2.1 创建 Mock 类
```dart
class MockDio extends Mock implements Dio {}
class MockAuthRepository extends Mock implements AuthRepository {}
```
`extends Mock implements X` —— `Mock` 提供 `noSuchMethod` 拦截,`implements X` 保证类型契约,编译期检查方法签名。

### 2.2 打桩:`when()`
```dart
when(() => mockDio.post(any(), data: any(named: 'data')))
    .thenAnswer((_) async => Response(
          requestOptions: RequestOptions(path: '/login'),
          statusCode: 200,
          data: {'token': 'abc123'},
        ));

// 同步返回值
when(() => cat.sound()).thenReturn('meow');
// 抛出异常
when(() => mockDio.get(any())).thenThrow(DioException(...));
```
⚠️ **必须用闭包包裹** `() => mock.method()`,而不是 `mock.method()` 本身——这是 mocktail 相对 mockito 最大的语法差异,闭包让 mocktail 能在真正调用前拦截参数。

### 2.3 验证:`verify()`
```dart
verify(() => mockDio.post('/login', data: any(named: 'data'))).called(1);
verifyNever(() => mockDio.delete(any()));
verifyInOrder([
  () => mockDio.get('/user'),
  () => mockDio.get('/settings'),
]);
```
⚠️ **一次 `verify` 会消耗掉对应的调用记录**——同一个调用被 verify 过一次后,再次对它 verify 会失败(因为已经被标记为"已验证",不会重复计入)。这点和 Jest 的 `toHaveBeenCalled` 不完全一样,写多断言时容易踩坑。

### 2.4 参数匹配器
```dart
any()                    // 匹配任意值
any(named: 'data')       // 匹配任意命名参数
any(that: startsWith('a')) // 结合 matcher 精确匹配
captureAny()              // 捕获参数用于后续断言
```

### 2.5 `registerFallbackValue()` —— 最容易漏掉的一步

**为什么需要:** `any()` 内部需要在没有真实调用发生时,提前准备一个"占位返回值"供 Dart 的静态类型系统满足非空校验。基础类型(`int`/`String`/`bool` 等)mocktail 已内置,但**自定义类型必须手动注册**,否则运行时抛出 `type 'X' not registered` 错误。

```dart
class FakeRequestOptions extends Fake implements RequestOptions {}

setUpAll(() {
  // 每个自定义类型只需注册一次,建议统一放在 setUpAll
  registerFallbackValue(FakeRequestOptions());
});
```
注意用的是 `Fake`,不是 `Mock`——`Fake` 表示"这个对象仅作为占位符,不需要打桩行为"。

---

## 3. 实战:结合你的 Dio + Result<T> + Riverpod 技术栈

### 3.1 Mock Dio,测试 Repository 层的 sealed exception 映射
```dart
class MockDio extends Mock implements Dio {}
class FakeRequestOptions extends Fake implements RequestOptions {}

void main() {
  late MockDio mockDio;
  late AuthRepository repository;

  setUpAll(() => registerFallbackValue(FakeRequestOptions()));

  setUp(() {
    mockDio = MockDio();
    repository = AuthRepository(dio: mockDio);
  });

  test('登录成功 → Result.success(AuthToken)', () async {
    when(() => mockDio.post(any(), data: any(named: 'data'))).thenAnswer(
      (_) async => Response(
        requestOptions: RequestOptions(path: '/login'),
        statusCode: 200,
        data: {'token': 'abc123'},
      ),
    );

    final result = await repository.login('a@b.com', 'pwd');

    expect(result, isA<Success<AuthToken>>());
    verify(() => mockDio.post('/login', data: any(named: 'data'))).called(1);
  });

  test('401 响应 → 映射为 UnauthorizedException', () async {
    when(() => mockDio.post(any(), data: any(named: 'data'))).thenThrow(
      DioException(
        requestOptions: RequestOptions(path: '/login'),
        response: Response(
          requestOptions: RequestOptions(path: '/login'),
          statusCode: 401,
        ),
        type: DioExceptionType.badResponse,
      ),
    );

    final result = await repository.login('a@b.com', 'wrong');
    final failure = result as Failure<AuthToken>;

    expect(failure.exception, isA<UnauthorizedException>());
  });
}
```
这套测试直接验证你 Dio 封装里那套 **sealed exception hierarchy → Result<T>** 的转换逻辑是否正确,不需要真实网络请求。

### 3.2 Mock Repository,测试 Riverpod Notifier
```dart
class MockAuthRepository extends Mock implements AuthRepository {}

void main() {
  test('登录成功 → state 变为 AsyncData', () async {
    final mockRepo = MockAuthRepository();
    when(() => mockRepo.login(any(), any()))
        .thenAnswer((_) async => Success(AuthToken('abc123')));

    final container = ProviderContainer(
      overrides: [authRepositoryProvider.overrideWithValue(mockRepo)],
    );
    addTearDown(container.dispose);

    final notifier = container.read(authNotifierProvider.notifier);
    await notifier.login('a@b.com', 'pwd');

    expect(container.read(authNotifierProvider), isA<AsyncData>());
  });
}
```
`overrideWithValue` 是 Riverpod 测试的标准手法——依赖图在 widget 树外,所以测试时不需要 pump 任何 widget,直接操作 `ProviderContainer` 即可,这也是之前聊过的"Riverpod 是响应式缓存框架"这一设计带来的直接好处。

---

## 4. 常见陷阱 ⚠️

| 陷阱 | 现象 | 解决 |
|---|---|---|
| 忘记 `registerFallbackValue` | 运行时抛 `type 'X' not registered` | 在 `setUpAll` 里为每个自定义类型注册一次 |
| Mock extension method | 调用不生效,走的还是真实实现 | extension 方法是静态解析,不经过 `noSuchMethod`,无法 mock;需要把逻辑挪进接口方法 |
| Mock 顶层函数/静态方法 | 无法打桩 | 包一层实例方法(Wrapper),类似 iOS 里给单例做协议抽象以便测试 |
| 调用未打桩的非空返回方法 | 抛运行时异常而非返回 null | 显式 `when()` 打桩,或用 `throwOnMissingStub` 主动暴露遗漏的桩 |
| 同一调用重复 `verify` | 第二次 verify 失败 | 每次 verify 只断言一次;需要多次判断用 `.called(n)` 一次性表达 |
| Mock Dart 3 的 `sealed`/`final` class | 编译报错,无法在库外 `implements` | 对 sealed 类型改为 mock 其依赖的接口,而不是 sealed 类本身 |

---

## 5. 面试 Q&A

**Q: Mocktail 和 Mockito 的本质区别是什么?**
考察点:对 Dart 语言特性(AOT 编译、tree-shaking)与测试框架设计取舍的理解。
标准答案:Mockito 依赖代码生成在编译期产出真实的 mock 子类(因为 Dart AOT 不支持运行时反射生成代理);Mocktail 利用 `Mock` 基类的 `noSuchMethod` 动态拦截调用,零代码生成,API 语法上用闭包包裹调用以支持参数匹配器。
iOS 对比:这与 OCMock 靠 Objective-C runtime 消息转发实现动态 mock、而 Swift 生态里的 Cuckoo/Mockingbird 反而需要代码生成的情况正好形成镜像对照——静态语言做动态 mock 通常两条路:要么走代码生成,要么走语言保留的动态派发能力。
常见误区:误以为 mocktail "更快"是因为跳过了 build_runner,实际两者运行时性能接近,差异主要在开发体验(无需等编译生成 `.mocks.dart`)。

**Q: 为什么 `when()`/`verify()` 要求传入闭包而不是直接调用?**
标准答案:闭包让 mocktail 能够在参数求值前拦截调用,从而让 `any()` 这类匹配器工作;同时闭包还承担捕获 `TypeError` 的作用,避免非空返回类型在打桩阶段直接抛出编译期无法预知的运行时类型错误。

---

## 后续学习方向建议
- Riverpod `Notifier`/`AsyncNotifier` 单元测试的完整 pattern(结合 `ProviderContainer.pump`)
- Golden test(iOS 对应 snapshot testing,如 SnapshotTesting 库)
- `mocktail_image_network` 处理 widget test 中的网络图片 mock
- Drift 数据库测试:内存数据库(`NativeDatabase.memory()`)vs Mock DAO 的取舍
