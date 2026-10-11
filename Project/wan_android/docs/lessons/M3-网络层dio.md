# M3 网络层 dio（拦截器 + Repository + 统一错误）

> 本课产出：一套真实项目级的网络层——容器作用域共享的 `Dio` 实例、日志/鉴权拦截器、
> `ProductsRepository`（UI 只调它、不碰 dio）、`sealed` 的统一错误模型 `AppException`。
> 首页从此拉的是 DummyJSON 的**真实数据**。**dio + Repository + 拦截器这三样，
> 是本项目复用率最高的基础设施，务必吃透。**

---

## 一、本课重点掌握（按重要程度排序）

### 1. Repository 模式：UI 永远不碰 dio ⭐⭐⭐

```dart
class ProductsRepository {
  final Dio _dio;
  // Dart 3.12 支持私有字段命名初始化参数，调用方仍使用 dio:。
  ProductsRepository({required this._dio});

  Future<ProductListResponse> fetchProducts({int limit = 20, int skip = 0}) =>
      requestJson(
        () => _dio.get('/products', queryParameters: {'limit': limit, 'skip': skip}),
        (data) => ProductListResponse.fromJson(data as Map<String, dynamic>),
      );
}
```

Repository ≈ iOS 的 ProductService，UI 只消费业务方法。构造函数显式注入 Dio；
生产由 `dioProvider` 提供，测试使用替代客户端或适配器。M3 原始实现采用单例兜底，
维护阶段已移除这项隐式依赖。

### 2. 拦截器：一次请求的三个统一切面 ⭐⭐⭐

`Interceptor` 有三个钩子，对应请求生命周期的三个时机（≈ OkHttp Interceptor / iOS 的 `URLProtocol`）：

```dart
class LoggingInterceptor extends Interceptor {
  void onRequest(options, handler)  { debugPrint('➡️ ...'); handler.next(options); }  // 发出前
  void onResponse(response, handler) { debugPrint('✅ ...'); handler.next(response); } // 收到后
  void onError(err, handler)         { debugPrint('❌ ...'); handler.next(err); }      // 出错时
}
```

- **每个钩子必须通过 `handler.next(...)`、`resolve(...)` 或 `reject(...)` 明确结束处理**，否则请求被"吞掉"永远发不出去——这是拦截器头号坑。
- 拦截器有顺序：本项目先加 `AuthInterceptor`（拼 token，M8）再加 `LoggingInterceptor`。
- `onRequest` 可以写成 `async`：dio 会一直等到你 `handler.next()` 才真正发请求，
  所以"异步读一次 Keychain 再决定加不加 header"能成立（见 M8 的 AuthInterceptor）。

### 3. 统一错误模型：把底层异常翻译成"人话" ⭐⭐⭐

`core/error/failure.dart` 只定义 Network / Server / Parse / Unknown 异常，
不 import Dio。`core/network/request_json.dart` 负责映射传输异常，再单独解码响应。
请求失败不能被一条宽泛的 catch 当成解析失败；解码边界仅捕获格式与类型错误。

```dart
final Response<dynamic> response;
try {
  response = await request();
} on DioException catch (error) {
  throw mapDioException(error);
}
// 随后单独 decode(response.data)，格式/类型错误映射为 ParseException。
```

UI 仍只面对 AppException，不依赖传输实现。

### 4. 分页参数：`skip`/`limit` 就是 offset 分页 ⭐⭐

- `limit`=每页条数，`skip`=跳过多少条（`= 已加载条数`）。下一页使用状态里的 `nextSkip`，由响应 `skip + products.length` 推进。
- 配 M2 信封的 `hasMore` getter 判断"还有没有下一页"，M4 的上拉加载直接用。
- 坑（真实项目高频）：**接第三方 API 时，路径参数/query 拼错不一定报错**——
  DummyJSON 的分类 slug 写错只会返回 `total: 0`（空结果），不会抛异常。排查时先打日志看真实 URL。

### 5. `res.data` 已是解析好的 Map，别再手动 `jsonDecode` ⭐

- dio 默认按 `Content-Type` 把响应体**已经**解析成 `Map`/`List` 了，直接喂给 M2 的 `fromJson`。
- 坑：又手动 `jsonDecode(res.data)` 会报"已经是 Map 不能再 decode"。记住 **dio 帮你 decode 了一层**。

---

## 二、新控件/工具速查表

| 概念/API | iOS 类比 | 怎么用 | 坑 |
|---|---|---|---|
| `Dio` 实例 | 封装好的 `URLSession` | `Dio(BaseOptions(baseUrl, timeout, headers))`，ProviderScope 内复用并随容器关闭 | 别每次请求 new 一个；baseUrl 末尾斜杠 + 路径开头斜杠会拼出双斜杠 |
| `BaseOptions` | `URLSessionConfiguration` | 设 `baseUrl`/`connectTimeout`/`receiveTimeout`/默认 `headers` | 不设超时默认可能很长；超时要连接+接收都设 |
| `Interceptor` | `URLProtocol` / OkHttp Interceptor | 继承它重写 `onRequest`/`onResponse`/`onError` | 每个钩子必须明确放行、返回或拒绝，否则请求被吞 |
| `dio.get(path, queryParameters:)` | `URLSession.dataTask` | `await dio.get('/products', queryParameters: {...})` | query 值别手动拼进 URL 字符串（编码问题），用 `queryParameters` |
| `DioException` / `DioExceptionType` | `URLError` | `on DioException catch (e)` + `switch (e.type)` | 只在 Repository 边界 catch，翻译成 AppException 再上抛 |
| `res.data` | `data`（但已解析） | 直接 `as Map<String, dynamic>` 喂 fromJson | 已被 dio 解析过，别再 `jsonDecode` |
| `debugPrint` | `print`（但更安全） | 打日志 | 生产环境的日志拦截器要按 Flavor 关掉（M12），避免刷屏/泄露 |

---

## 三、代码地图

```
lib/core/
  network/
    dio_client.dart           dioProvider + authStorageProvider；按 Flavor 配置并挂 Auth+Logging 拦截器
    logging_interceptor.dart  请求/响应/错误日志（三钩子 + handler.next）
    auth_interceptor.dart     自动拼 Bearer token（M8 才真正生效）
  error/failure.dart          sealed AppException（不依赖 Dio）
lib/features/products/data/
  products_dependencies.dart   Repository/Cache 的装配 provider
  products_repository.dart     fetchProducts / fetchProduct /
                               fetchByCategory / searchProducts
lib/features/categories/data/categories_repository.dart  分类列表请求
```

> M3 的原始单例属于课程历史；当前已由 Riverpod 容器装配，见 M4 与架构维护说明。

---

## 四、自测清单

1. UI 为什么绝不该直接 `catch (DioException)`？错误该在哪一层被翻译？
2. 拦截器的三个钩子分别在什么时机触发？漏了 `handler.next()` 会怎样？
3. Repository 构造函数为什么要求显式传入 `dio:` 参数？它让 M11 的测试能做什么？
4. 第二页请求的 `skip` 应该传什么值？怎么判断还有没有下一页？
5. 分类 slug 拼错了，DummyJSON 会报错吗？该怎么排查？
6. 为什么 `res.data` 不用再 `jsonDecode`？

---

## 五、练习

给 `LoggingInterceptor` 的 `onResponse` 加上"请求耗时"打印（`onRequest` 时在
`options.extra` 里塞一个开始时间戳，`onResponse` 里算差值）。做完你会更理解
"拦截器是贯穿一次请求首尾的切面"这件事。
