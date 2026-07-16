# S6 · 结课作业：Riverpod 版 MiniShop

> StateLab 第七课（结课）。原定学员独立实现 v4_riverpod、讲师只出验收 checklist + code review；2026-07-16 改为一次性完成模式——讲师直接产出**参考实现**（`versions/v4_riverpod/`），本讲义保留验收 checklist（自查用）并附 code review 记录。
> 深度长文见 [s6-riverpod](../tech/s6-riverpod.md)（六章骨架与 s2–s4 同规格）；横向定位见 [s5 §0/§1](../tech/s5-横向对比与选型.md)。WanShop 主栈已用 Riverpod codegen，本参考实现刻意用**手写 Notifier** 版——两种写法运行时等价，差异清单见 s6 §2.1（注意 codegen 默认 autoDispose 与手写相反）。

## 一、验收 Checklist（对照设计文档第 4 节，逐条自查）

**功能规格（与 v0–v3 逐像素一致）**

- [x] 场景①：分页加载（每页 20）、下拉刷新、触底加载更多、失败重试、加载更多失败静默
- [x] 场景②：收藏心形 = 页面 setState（不上全局，五版一致）
- [x] 场景③④：跨页共享购物车、增减/滑删/清空、派生值现算
- [x] 场景⑤：搜索防抖 400ms、丢过期响应、失败落 error
- [x] AppBar 角标全页面常驻实时 +1；文案与各版一致（标题后缀 `· v4 Riverpod`）
- [x] S0 学员 bug 剧本回归：详情 → 清空 → 返回，角标清零

**Riverpod 专项**

- [x] 服务 DI：`Provider<ProductApi>` + ProviderScope `overrides` 注入（生产/测试同口子）
- [x] 购物车：`Notifier` + 不可变 state（Equatable），版本级（非 autoDispose，随 Scope 生死）
- [x] 列表:`AsyncNotifier`——**build 即首载**、AsyncValue 内建三态、`ref.refresh(provider.future)` 做下拉刷新
- [x] 列表/搜索:`autoDispose` = 页面级生命周期（最后一个 watcher 离场即销毁）
- [x] 角标：`select((s) => s.totalCount)` 字段级订阅
- [x] 防抖 Timer 挂 `ref.onDispose` 清理；防抖时长走 provider（测试 override 提速）
- [x] 跨路由：`UncontrolledProviderScope` 共享容器（scope 在版本根、路由挂 Navigator 下的必然结果，对照 v1/v2 `.value`）
- [x] 测试：`ProviderContainer` + overrides 纯 Dart 测状态层（14 测），widget 流程测试 2 测

**门禁**

- [x] `flutter analyze` 0 issue；全量 `flutter test` 绿（92 测）
- [x] shared/ 纯净：纯展示 Widget 零状态库 import（五版共用到底）

## 二、Code Review 记录（讲师视角，值得注意的四处）

1. **`product_list_notifier.dart` 的 loadMore 失败分支**：不能把 state 打成 `AsyncError`——那会让整页掉进全屏错误态，违背"加载更多失败静默"的冻结语义。参考实现是在 `AsyncData` 里原地翻 `loadingMore: false`。**这是 AsyncValue 的一个使用心法：AsyncError 是"整体失败"，局部失败要自己在 data 里建模。**
2. **Riverpod 3 的自动重试**：build 失败默认按指数退避自动重跑。生产是免费的健壮性；测试里抓 AsyncError 必须 `ProviderContainer(retry: (c, e) => null)` 关掉（`product_list_notifier_test.dart` 有注释）。WanShop 里如果见过"错误页闪一下自己好了"，根源就是它。
3. **`pushWithScope` 的取舍**：把 ProviderScope 提到 MaterialApp 之上可根治（真实单方案 App 的标准做法），本工程为五版隔离把 scope 压在版本根，代价就是每条 push 要 `UncontrolledProviderScope` 包一层——和 S2 §5.6 的 `.value` 取舍是同一道题的两次出现。
4. **`state.value` vs 旧版 `valueOrNull`**：riverpod 3 把两者合并成 `value`（可空、错误态也保留旧数据）。迁移旧代码时这是高频编译错误点。

## 三、结课总结：五版走完后你应该带走的三张图

1. **依赖宿主图**（s5 §0 表第二行）：构造传参 → 树上（InheritedWidget 系）→ 树外可变表（GetX）→ 树外声明式图（Riverpod）。每个方案的甜与坑都从"依赖住哪"派生。
2. **状态可变性图**：可变+通知（setState/Provider/GetX）vs 不可变+替换（Bloc/Riverpod）。S2 练习 2 那笔账——判等/回放/收窄 vs copyWith 税——是横贯 S3/S6 的主线。
3. **选型决策树**（s5 §4）：背条件，不背结论。面试标准答法 = 约束 → 对比 → 代价 → 兜底（s5 §6 题 20）。

**课程闭环自查**：能不看代码说出"同一个加购动作五种写法"（s5 §1.1）→ 能讲清防抖在五版里的三种命运（手写 Timer / EventTransformer / worker+序号）→ 能给一个新项目做带代价声明的选型——三条全过，结课。

## 四、延伸（课程之外，自选）

- 给 v4 换 codegen 写法（`riverpod_annotation` + `riverpod_generator` + build_runner），对照手写版 diff——WanShop 同款工具链。
- 用 `keepAlive()` 试验 autoDispose 的例外（如"搜索结果缓存 5 分钟"）。
- 把 S2 的 RebuildBadge 实测在 v4 上重跑一轮，验证 select 的粒度与 v1 Selector 持平。
