# S4 · GetX 版 MiniShop

> StateLab 第五课。本课交付：`versions/v3_getx/` 完整 MiniShop（规格与 v0/v1/v2 一致）+ 三个控制器单测。
> 深度长文见 [s4-getx](../tech/s4-getx.md)；Bloc 对照回看 [s3-bloc](../tech/s3-bloc.md)。

## 一、本课重点

### 1. 一句话总纲

**GetX 把依赖从 Widget 树上搬进了一张全局注册表**（`Get.put`/`Get.find`，不要 context）。最直观的对照：v1/v2 每条 push 的 `.value` re-provide **全删了**——购物车页、详情页想拿 cart，任何地方 `Get.find` 直捞。甜头和账单都从这一条派生：

| 甜头 | 账单 |
|---|---|
| 跨路由零 re-provide | 依赖不跟树走：忘 put / 早 delete = 运行时炸 |
| 不要 context，回调/纯 Dart 随处取用 | 编译器和 Inspector 都看不见依赖关系 |
| 样板全场最少 | 生命周期手动管（put/delete 配对），忘一处就泄漏/串味 |

### 2. 双轨：自动挡 vs 手动挡（本课主线）

| | 自动挡 Obx + Rx | 手动挡 GetBuilder + update() |
|---|---|---|
| 字段 | `.obs`（RxList/RxBool…） | 普通 Dart 字段 |
| 通知 | 赋值自动发流（相同值去重） | 改完手动 `update([ids])` |
| 订阅 | Obx 闭包**读到哪个 Rx 订哪个**（隐式收集） | GetBuilder 按类型 + id 分组 |
| 本质 | RxSwift 式响应式 | "setState 挪进 controller" |
| 工程分配 | CartGetxController（跨页多处订阅）、SearchGetxController | ProductListGetxController（单页、转移清晰） |

手动挡的 `update(['footer'])` 定向刷新 = buildWhen 的手工版：loadingMore 翻转只惊动 footer，列表本体纹丝不动。**坑**：无参 `update()` 和带 id 的分组是两张隔离的表，互相刷不到——所以列表控制器所有通知显式带 ids。

### 3. 本课三大坑（都在代码里现场演示）

1. **RxList 感知不到元素内部变化**：`items[i].quantity += 1` 后必须 `items.refresh()`（cart_getx_controller.dart 两处）。v2 的不可变 CartLine 从类型上杜绝了这坑——GetX 回到可变世界，坑就回来了。单测 `cart_getx_controller_test.dart` 最后一测直接复现"不 refresh 流就不发"。
2. **worker 不随 controller 销毁**：debounce worker 持有 Rx 订阅，onClose 里手动 `_worker.dispose()`。
3. **GetX 没有 switchMap**：防抖 worker 给了，"丢过期响应"还得手写请求序号（v1 同款代码回归了——对照 v2 一个 EventTransformer 一锅端）。

### 4. isClosed：守卫的第三种形态

同一个"页面没了异步才回来"的病，三个方案三种药：v1 手写 `_disposed`；v2 框架全接管（close 后 emit 自动 no-op）；v3 框架给了 `isClosed` 标志位**但判断自己调**（`_safeUpdate` / `_search` 里的 `if (isClosed) return`）。

### 5. 全家桶边界（专节，见技术文档 §5）

GetX 还带路由/DI/SnackBar/i18n 全家桶。本工程**只用状态管理，不用 GetMaterialApp/Get.to**——五版本共存的主导航不能绑单一方案，这也证明了 GetX 状态管理可拆开用。争议五条（全局单例、依赖不可见、生命周期脱钩、魔法难排查、单包风险）读技术文档。

## 二、代码地图

```
state_lab/lib/versions/v3_getx/
  v3_shop_root.dart                  # ⭐ 无 Provider 挂树!initState Get.put / dispose Get.delete
  state/
    cart_getx_controller.dart        # 自动挡:RxList<可变CartItem> + refresh() 坑现场
    product_list_getx_controller.dart# 手动挡:update(['list','footer']) 定向刷新 + isClosed 守卫
    search_getx_controller.dart      # debounce worker + 手写序号丢过期(GetX 无 switchMap)
  pages/
    product_list_page.dart           # 外层 GetBuilder 只当 init 宿主;body id:'list'/footer id:'footer'
    product_detail_page.dart         # Obx 角标;收藏仍 setState
    cart_page.dart                   # Obx 整页(自动挡);零参数零 re-provide
    search_page.dart                 # 页面级 controller 手动 put/delete
state_lab/test/versions/v3_getx/     # 14 个控制器单测(含 refresh 语义/定向刷新计数)
state_lab/test/versions/v3_cart_flow_test.dart  # 主流程+回归,tearDown(Get.reset)
```

对照：`git diff <S3收官> HEAD -- state_lab/lib/versions/`。v3 与 v2 的 diff 就是本课全部内容。

## 三、控件/API 速查表（本课新面孔）

| API | iOS 类比 | 怎么用 | 易踩的坑 |
|---|---|---|---|
| `.obs` / Rx 家族 | `BehaviorRelay`/`@Published` | `final query = ''.obs` | RxList 元素内部变化要 `refresh()` |
| `Obx(() => W)` | Rx `bind` UI | 闭包读 Rx 即订阅 | 闭包没读 Rx 直接抛错；回调里读不算订阅 |
| `GetBuilder<C>(id:, init:)` | 手动 reloadData | init 托管创建+autoRemove | 无参 update 刷不到带 id 的 |
| `update([ids])` | — | 手动挡通知，ids 点名 | close 后调用要 isClosed 守卫 |
| `Get.put/find/delete` | 全局 DI 容器 | 树外注册表 | 没注册就 find 运行时炸；忘 delete 泄漏/串味 |
| `Get.lazyPut` | 懒注册 | 首次 find 才建 | ≈ Provider 的 lazy |
| `GetxController` | ViewModel | onInit/onReady/onClose/isClosed | 直接 new 不触发生命周期（测试手动调 onInit） |
| workers `debounce/interval/ever/once` | Rx 算子 | onInit 挂，Worker 收好 | onClose 手动 dispose |
| `Bindings`/`GetMaterialApp` | — | 路由级依赖打包 | 绑定 GetX 路由，本工程未用（边界见 tech §5） |

## 四、关键实验（模拟器上做）

1. **零 re-provide 体感**：对照 v1/v2 的 `_openCart`（都要 `.value` 包一层）和 v3 的（一行裸 push）——树外注册表的甜头。
2. **refresh() 坑复现**：把 `cart_getx_controller.dart` add 里重复加购分支的 `items.refresh()` 注释掉 → 列表页对同一商品连点加购，角标停在 1 不动（数据在涨界面不知道）；恢复。
3. **定向刷新**：触底加载更多，footer 的转圈出现/消失，列表本体的 RebuildBadge 不涨（如果给 body 挂个 badge 的话）——`update(['footer'])` 只惊动 footer。
4. **串味实验**：把 `V3ShopRoot.dispose` 里的 `Get.delete<CartGetxController>` 注释掉 → 加购几件、退出 v3 再进——购物车还是满的（旧 controller 仍在全局表里）；恢复。这就是"生命周期不跟树走"的直观代价。
5. 常规场景表照走：分页/刷新/防抖/购物车增删/合计/详情清空返回。

## 五、自测清单

1. Obx 的依赖收集是怎么实现的？为什么闭包里没读 Rx 会抛错、回调里读不算订阅？
2. RxList 改元素内部字段为什么界面不动？两种解法（refresh vs 不可变元素）各是什么思路？
3. `update()` 无参和 `update(['id'])` 的关系？为什么工程里所有通知都显式带 ids？
4. Get.put/lazyPut/find/delete 各在什么时机触发 onInit/onClose？
5. debounce worker 替掉了 v1 的什么？丢过期为什么还要手写序号？
6. isClosed 守卫防什么？对照 v1 的 `_disposed` 和 v2 的"框架接管"，三种形态差在哪？
7. v3 为什么完全没有 re-provide？甜头的账单是哪三条？
8. 不用 GetMaterialApp 损失了什么？为什么本工程主导航不绑 GetX？
9. GetX 怎么做"字段级不刷"（totalCount 没变角标就不刷）？能开箱做到吗？
10. GetX 的社区争议五条，你站哪边、为什么？

（答案见 `自测答案/S4-自测答案.md`。）

## 六、课后练习

1. **手动挡改自动挡**：把 `ProductListGetxController` 改成全 `.obs` 字段 + 页面 Obx（不用 update/GetBuilder），跑通场景①。对比两版代码量与可读性，体会"双轨各自适合什么"。改回来（或留分支）。
2. **字段级判等实验**：给购物车角标做"count 没变不刷"——把 totalCount 单独做成 `RxInt`，在 cart 的每个方法里同步它（或用 `ever(items, ...)` worker）。对比 v1 `Selector`/v2 `BlocSelector` 的一行写法，体会"GetX 缺字段级判等件"是什么意思。
3. **进阶思考（带去 S5/S6）**：GetX 把依赖搬出树换来了便利，Riverpod 也把依赖搬出了树（Provider 容器同样不在 Widget 树上）——但两者的安全性口碑天差地别。差在哪？（提示：全局可变注册表 vs 编译期声明的不可变 provider 图；运行时 find vs 类型系统保证的 ref.watch。）S6 写 v4 时找答案。
