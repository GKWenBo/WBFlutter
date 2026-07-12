# S2 · Provider 版 MiniShop

> StateLab 第三课。本课交付:`versions/v1_provider/` 完整 MiniShop(规格与 v0 一致)+ 三个可单测的状态层模型。
> 深度长文见 [s2-provider](../tech/s2-provider.md);地基回看 [s1-状态管理的地基](../tech/s1-状态管理的地基.md)。

## 一、本课重点

### 1. 一句话总纲

**Provider = S1 手写版 + 生命周期托管 + 粒度工具 + 更好的报错,零私有魔法。**你在 S1 亲手写过它的每个零件——本课的全部内容就是这张对照表:

| S1 你手写的 | S2 Provider 给你的 | 多出来什么 |
|---|---|---|
| Stateful 宿主:建 controller/dispose/挂树 | `ChangeNotifierProvider(create:)` | 托管——根变 Stateless |
| `MiniProvider.of()` | `context.watch<T>()` | 同一件事 |
| `MiniProvider.read()` | `context.read<T>()` | 同一件事 |
| Builder 圈依赖块 | `Selector` / `context.select` | 粒度从"块"到"**字段**" |
| 每条 push 手动再包一层 | `ChangeNotifierProvider.value` | 同一姿势的官方名字 |
| assert "这条路由包了吗?" | `ProviderNotFoundException` | 报错自带排查清单 |
| api 构造函数手递 | `Provider<ProductApi>` 纯 DI | 服务也走树,页面零服务参数 |

### 2. 决策口诀(写代码时对号入座)

- **回调必 `read`**(watch 在回调里直接抛错);
- **整页依赖用 `watch`**(购物车页:整页都在展示 cart,页面级粒度合理);
- **单字段用 `Selector`/`select`**(角标只看 totalCount——值不变就不重建,连 notifyListeners 都吵不醒它);
- **create 新建托管,`.value` 复用不托管**——用反了要么泄漏要么二次 dispose(高频面试题+高频事故)。

### 3. 状态层出 UI:本课第二大红利

场景①(三态分页)⑤(防抖搜索)从页面 State 搬进 `ProductListModel`/`SearchModel`:页面瘦成"转发+展示",逻辑变成纯 Dart 对象——**15 个模型单测零 pumpWidget**,防抖用 fake_async 拨表针不用真等 400ms。类比 iOS:逻辑从 VC 搬进 ViewModel 后终于能写单测了。
模型侧新习惯:`_disposed` 守卫 ≈ 模型版 `mounted`(页面 pop 托管 dispose 后,在途请求回来不能再 notify)。

### 4. 三个作用域(v1 的骨架)

| 作用域 | 对象 | 挂哪 | 生命周期 |
|---|---|---|---|
| 版本级 | ProductApi、CartModel | V1ShopRoot 的 MultiProvider | 进版本建,退版本销 |
| 页面级 | ProductListModel、SearchModel | 各页面头顶 create | **pop 即 dispose**(Timer 一起带走) |
| 页面私有 | 收藏心形、TextEditingController | State | "一个人看的状态不上树" |

### 5. S1 思考题公布答案

**把 provider 提到 MaterialApp 之上:** 能删掉所有 `.value` re-provide 样板;代价是状态生命周期=App(热重启才重置)+五版本共享一棵树互相污染。单方案 App 通常提上去;**本工程为版本隔离,选择每条 push re-provide**——所以你在 v1 里看到的 `.value` 和 S1 手写的那行是同一姿势。

## 二、代码地图

```
state_lab/lib/versions/v1_provider/
  v1_shop_root.dart                  # ⭐ StatelessWidget!MultiProvider:api(纯DI)+cart
  state/
    cart_model.dart                  # 与 S1 CartController 一字不差(刻意:状态层不用为 Provider 改一行)
    product_list_model.dart          # 场景①:三态+分页+_disposed 守卫
    search_model.dart                # 场景⑤:防抖 Timer+序号丢过期全在模型里
  pages/
    product_list_page.dart           # 页面级 create..loadFirst / Selector 角标 / Consumer body
    product_detail_page.dart         # Builder+context.select 角标;收藏仍 setState
    cart_page.dart                   # context.watch 整页依赖(Stateless)
    search_page.dart                 # 页面级 SearchModel;TextField 直连 onQueryChanged
state_lab/test/versions/v1_provider/ # 15 个模型单测(TDD)
state_lab/test/versions/v1_cart_flow_test.dart  # 主流程+学员bug剧本,与 v0 版逐行同构
```

对照:`git diff d444edd HEAD -- state_lab/lib/versions/`(d444edd = S1 收官)。v1 与 v0.5 的 diff 就是本课全部内容。

## 三、控件/API 速查表(本课新面孔)

| API | iOS 类比 | 怎么用 | 易踩的坑 |
|---|---|---|---|
| `MultiProvider` | 链式 `.environmentObject` | providers 列表平铺 | 顺序有意义:后者可 read 前者 |
| `ChangeNotifierProvider(create:)` | `.environmentObject` + 托管 | 新建模型,自动 dispose | 默认 **lazy**:首次被消费才跑 create;要即刻创建传 `lazy: false` |
| `ChangeNotifierProvider.value` | 传已有 ObservableObject | 跨路由 re-provide | **不托管 dispose**;别拿它包新建对象 |
| `Provider<T>` | Environment 放只读依赖 | 服务/配置纯 DI | 不通知;想通知换 ChangeNotifierProvider |
| `context.watch<T>()` | `@EnvironmentObject` | build 里取值+订阅 | 回调里调必抛错 |
| `context.read<T>()` | 拿对象不观察 | 回调/initState | build 里滥用会不跟新 |
| `context.select<T,R>()` | 观察单个 `@Published` | 选字段比 `==` | 选可变集合引用:恒等永不重建/新建恒不等次次重建。**选标量** |
| `Consumer<T>` | 局部观察包装 | builder(ctx, model, child) | child 参数缓存大子树,别浪费 |
| `Selector<T,R>` | 同上+字段版 | selector 返回标量 | 同 select 的集合坑 |
| `fake_async`(测试) | XCTest 的时间控制 | `fakeAsync((async) { ...; async.elapse(...); })` | 别忘 `flushMicrotasks` 让 Future 落地 |

## 四、关键实验(模拟器上做)

1. **字段级粒度**:v1 列表页加购一件 → `列表角标` +1、商品卡不动(和 v0.5 表现一致);再进购物车页增减数量后返回列表——角标数没变的话,**Selector 连 build 都不跑**(v0.5 的 Builder 版本:notifyListeners 一响它就得跑一遍再发现没变化)。
2. **ProviderNotFoundException 体验**:临时把详情页 `_openCart` 里的 `.value` 包装删掉 → 点购物车红屏,**读一遍报错文案**——它列了四种可能原因,对照 S1 手写 assert 的一句话,体会"更好的报错"值多少钱。改回来。
3. **页面级 dispose**:搜索页输入一半直接返回——SearchModel 连同防抖 Timer 被托管销毁,控制台无 "used after being disposed"(对照 v0 要手动 dispose Timer)。
4. 常规场景表照走:分页/刷新/防抖/购物车增删/合计/详情清空返回。

## 五、自测清单

1. `watch` 在事件回调里调会发生什么?为什么框架要拦?
2. `create` 和 `.value` 的唯一本质区别是什么?两种用反各导致什么事故?
3. `Selector` 判定重不重建的完整流程?`(c) => c.items` 这种 selector 错在哪、两种错法?
4. 页面级 provider 的模型什么时候被 create、什么时候被 dispose?lazy 默认值带来什么行为?
5. `_disposed` 守卫防什么?对应页面侧的什么?没有它会看到什么报错?
6. 搜索页为什么连 api 构造参数都不用传了?`Provider<T>` 和 `ChangeNotifierProvider<T>` 差在哪?
7. v1 里哪些依赖是字段级、哪些是页面级?各自为什么这么选?
8. `Consumer` 的 child 参数解决什么问题?
9. MultiProvider 里 provider 的顺序什么时候有意义?
10. Provider 的两个上限(Riverpod 的立项理由)是什么?

(答案先自己写,过关后归档 `自测答案/`。)

## 六、课后练习

1. **粒度体感**:把列表页 `Selector` 临时改成在 `_ListScaffold.build` 顶部 `context.watch<CartModel>()`,加购一件观察 RebuildBadge——整页计数暴涨(商品卡全员陪跑);改回来,记住这两个数字(S5 对比素材)。
2. **进阶思考(带去 S3)**:CartModel 的方法直接改字段再 notify——"改哪了"只有方法作者知道,监听者一律全量重查。如果规定**状态必须是不可变对象、每次变更整体替换**,会换来什么(提示:新旧状态可以 diff、可以回放、可以断言"状态转移")、失去什么?——这就是 Bloc 的世界观,S3 见。
