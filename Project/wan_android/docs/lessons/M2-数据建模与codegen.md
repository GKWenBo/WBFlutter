# M2 Dart 进阶 + 数据建模（json_serializable 代码生成）

> 本课产出：把 M1 的假数据换成正经模型——`Product` / `ProductListResponse` /
> `Category` / `CartItem`，配 `json_serializable` + `build_runner` 自动生成
> `fromJson`/`toJson`（≈ Dart 版 Codable），并顺带把 `sealed class`、空安全、
> `Future` 这几个 Dart 的核心特性讲透。**这一课是后面所有网络/存储模块的地基。**

---

## 一、本课重点掌握（按重要程度排序）

### 1. Codable 的 Dart 版：注解 + 代码生成，而不是编译器内建 ⭐⭐⭐

Swift 的 `Codable` 是编译器内建的；Dart 没有，靠**代码生成**补上：

```dart
part 'product.g.dart';          // ① 声明"生成文件拼进来"

@JsonSerializable()             // ② 打标记
class Product {
  final int id;
  final String title;
  // ...字段
  factory Product.fromJson(Map<String, dynamic> json) => _$ProductFromJson(json);
  Map<String, dynamic> toJson() => _$ProductToJson(this);   // ③ 委托给生成的函数
}
```

然后跑一次代码生成，`_$ProductFromJson`/`_$ProductToJson` 就有了：

```bash
dart run build_runner build --delete-conflicting-outputs
# 边写边生成用 watch，改完存盘自动重跑：
dart run build_runner watch  --delete-conflicting-outputs
```

- 心智模型：**你只维护字段声明，样板 JSON 代码交给生成器**——这就是 Codable 的等价物。
- 三处缺一不可：`part 'xxx.g.dart'` + `@JsonSerializable()` + `factory fromJson`/`toJson`。
  写完先别管 IDE 报红（`_$ProductFromJson` 还不存在），**跑完 build_runner 就消红**。

### 2. 分页信封（envelope）单独建模，别把它塞进业务模型 ⭐⭐⭐

DummyJSON 的列表接口返回的不是纯数组，是个"信封"：

```json
{ "products": [ {...}, ... ], "total": 194, "skip": 0, "limit": 20 }
```

- 建 `ProductListResponse` 专门接这个信封，`products` 字段声明成 `List<Product>`，
  **代码生成会自动对每个元素递归调用 `Product.fromJson`**（≈ Codable 的自动嵌套解码）。
- 把 `total/skip/limit` 留在信封上，配一个业务 getter `bool get hasMore => skip + products.length < total`，
  M4 的上拉分页直接用它判断"还有没有下一页"。
- 反面教材：把 `total/skip` 硬塞进 `Product` 或用裸 `List<Product>` 接——分页信息就丢了。

### 3. 业务派生数据放模型的 getter 上 ⭐⭐

```dart
double get discountedPrice => price * (1 - discountPercentage / 100);
```

- 折后价这种"从已有字段算出来"的数据，做成模型的**计算属性**，别在每个用到的页面里重算。
  ≈ Swift 给 struct 加 computed property / extension。
- 好处：折扣算法只有一处，UI 侧永远拿 `product.discountedPrice`，改算法只改一行。

### 4. 空安全：`String?` 就是 `Optional`，但更严 ⭐⭐

- Dart 的空安全和 Swift 几乎一模一样：`String` 不可为空，`String?` 可空。
  DummyJSON 有些商品没有 `brand`/`tags`，就声明成 `String? brand` / `List<String>? tags`。
- 用可空值前要"消空"：`?.`（可空链）、`??`（默认值）、`!`（强解包，≈ Swift 的 `!`，慎用）。
- 坑：**`!` 用错就是运行时崩溃**，和 iOS 一模一样。能用 `??` 给默认值就别 `!`。

### 5. `sealed class`：Dart 版的"有限枚举关联值" ⭐⭐

- M2 学的 `sealed class`（M3 用它建统一错误模型 `AppException`）≈ Swift 带关联值的 enum：
  子类是**有限、封闭**的一组，编译器能对它做**穷尽 switch**（漏掉一种分支就报错）。

```dart
sealed class AppException implements Exception { ... }
class NetworkException extends AppException { ... }
class ServerException  extends AppException { final int? code; ... }
// 用的时候：switch (e) { NetworkException() => ..., ServerException() => ..., ... }
// 少写一个分支编译器就拦你——这是 sealed 相比普通继承的最大价值。
```

### 6. `Future` / `async`-`await` ≈ Swift Concurrency ⭐⭐

- `Future<T>` ≈ Swift 的 `async` 函数返回值 / `Task`；`await` 用法几乎一致。
- 关键差异：Dart 是**单线程事件循环**（≈ 主 RunLoop）。`await` 不开新线程，只是"挂起等结果"。
  CPU 密集计算要真并行得用 `Isolate`（≈ 独立内存的 worker，M13 谈），普通网络 IO 用 `await` 就够。

---

## 二、新控件/工具速查表

| 概念/工具 | iOS 类比 | 怎么用 | 坑 |
|---|---|---|---|
| `@JsonSerializable()` | `Codable` | 打在 class 上 + 配 `fromJson`/`toJson` + `part '.g.dart'` | 三件套缺一不可；改完字段要重跑 build_runner，否则用的是旧生成代码 |
| `build_runner` | 无（Codable 内建，Dart 要外挂生成） | `dart run build_runner build --delete-conflicting-outputs` | 冲突时加 `--delete-conflicting-outputs`；`.g.dart` 是产物，改它没用（下次生成会覆盖） |
| `part` / `part of` | 无直接对应 | 把生成文件拼进当前库文件 | 路径要和源文件同名（`product.dart`→`product.g.dart`）；写错名字生成不进来 |
| `sealed class` | Swift enum with associated values | 定一组封闭子类，配穷尽 `switch` | 子类必须和父类同文件；非 sealed 的继承 switch 编译器不强制穷尽 |
| `String?`（空安全） | `Optional`/`String?` | `?.`/`??`/`!` 三件套消空 | `!` 强解包空值即崩；JSON 里"可能缺的字段"一律声明可空 |
| `Future<T>` / `await` | `async`/`await` / `Task` | `await someFuture()` | 单线程事件循环；`await` 不等于开线程，CPU 重活要 Isolate |
| `@JsonKey(name:)` | `CodingKeys` | 字段名和 JSON key 不一致时映射：`@JsonKey(name: 'user_id') final int userId` | 忘了配，驼峰字段接不到蛇形 JSON key，值会是 null/报错 |

---

## 三、代码地图

```
lib/features/products/
  domain/product.dart               Product（@JsonSerializable + discountedPrice getter）
  data/product_list_response.dart   分页信封（products/total/skip/limit + hasMore）
lib/features/categories/domain/category.dart   Category
lib/features/cart/domain/cart_item.dart        CartItem（快照 + copyWith，M7 用）
生成产物（勿手改）：*.g.dart 由 build_runner 产出
运行：dart run build_runner build --delete-conflicting-outputs
```

> 分层约定：**纯业务模型放 `domain/`**（Product/Category/CartItem），
> **贴着接口结构的 DTO/信封放 `data/`**（ProductListResponse）。
> 小项目里两者常常长得像，但语义分开：domain 是"我的业务对象"，data 是"接口长什么样"。

---

## 四、自测清单

1. Dart 没有内建 Codable，靠什么补上？三处必写的东西分别是什么？
2. 列表接口返回的是"信封"而不是纯数组，为什么要单独建 `ProductListResponse`？
3. `ProductListResponse.products` 声明成 `List<Product>` 后，代码生成帮你做了什么？
4. 折后价为什么做成模型 getter，而不是在每个页面里 `price * (1-...)`？
5. `sealed class` 相比普通父类继承，多给了你什么编译期保证？
6. 改了 `Product` 的字段却忘了重跑 build_runner，会发生什么？

---

## 五、练习

给 `Product` 加一个"是否有折扣"的派生 getter（`bool get onSale => discountPercentage > 0`），
再故意改一个字段名但不跑 build_runner，观察 IDE 报红/运行报错，然后跑一次 `build_runner build` 消掉它——
亲手体会"改模型 = 要重新生成"这条纪律。
