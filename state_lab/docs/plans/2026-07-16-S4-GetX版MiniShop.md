# S4 GetX 版 MiniShop 实施计划

> 2026-07-16。自本课起改为一次性完成模式（学员自行阅读学习），计划精简为任务清单 + 接口 + 教学点；完整代码直接进工程，门禁不变：`flutter analyze` 0 issue + 全量 `flutter test` 绿。

**Goal:** `versions/v3_getx/` 完整实现 MiniShop（规格与 v0/v1/v2 逐像素一致，AppBar 后缀 `MiniShop · v3 GetX`），双轨覆盖 GetBuilder 手动挡 / Obx+Rx 自动挡；专节讲全家桶边界；技术文档 s4。

**Architecture 与教学点分配：**

| 状态件 | 挡位 | 教学点 |
|---|---|---|
| `CartGetxController` | **自动挡**：`RxList<CartItem>`（复用 shared 的**可变** CartItem） | ①`.obs` 响应式；②经典坑：改元素内部字段 RxList 不感知 → `items.refresh()`；③与 v2 不可变对照——GetX 回到可变世界 |
| `ProductListGetxController` | **手动挡**：普通字段 + `update()`，页面 `GetBuilder` | ①手动挡 = "setState 挪进 controller"；②`update(['id'])` 定向刷新收窄重建（对照 Selector/buildWhen） |
| `SearchGetxController` | 自动挡 + **workers** | ①`debounce()` worker 替 Timer；②GetX 没有 switchMap——丢过期仍要手写序号（对照 Bloc restartable 的缺口） |
| `V3ShopRoot` | `Get.put` / `Get.delete`（StatefulWidget 手动管理） | ①不依赖 context 的全局注册表：跨路由 **零 re-provide**（v1/v2 的 `.value` 全删了）；②代价：依赖不跟树走，退出版本必须手动 `Get.delete` 防互染；测试必须 `Get.reset()` |
| 页面级 controller | 列表 `GetBuilder(init:)` 托管 / 搜索页 initState `Get.put`+dispose `Get.delete` | 没有 GetMaterialApp 就没有路由绑定的 smart management——手动管或 GetBuilder autoRemove |

**约束照旧：** shared 纯净；五场景归属不变（②收藏 setState）；对外方法名 add/changeQty/remove/clear + totalCount/totalPrice/isEmpty（S5 对照）；v0–v2 不改；门禁测试 `version_list_page_test.dart` 锁定断言 v3→v4；主工程导航不绑 GetX（不用 GetMaterialApp/Get.to，技术文档讲边界）。

## Tasks

- [ ] **Task 1** `state/cart_getx_controller.dart` + 单测（RxList/refresh 通知语义各一测）——含"改内部字段不 refresh 则流不发"的教学测试
- [ ] **Task 2** `state/product_list_getx_controller.dart` + 单测（手动挡状态转移 + update 监听计数）
- [ ] **Task 3** `state/search_getx_controller.dart` + 单测（debounce worker 真时钟可注入 + 序号丢过期 + 失败落 error）
- [ ] **Task 4** 根 + 四页装配（Obx 角标 / GetBuilder body / workers 搜索），analyze 0
- [ ] **Task 5** 注册表解锁 v3 + 门禁测试更新（锁定断言换 v4）+ v3 主流程/回归测试（Get.reset 隔离）
- [ ] **Task 6** 技术文档 `docs/tech/s4-getx.md`（六章骨架 + 全家桶边界专节）
- [ ] **Task 7** 讲义 `docs/lessons/S4-GetX版MiniShop.md` + 自测答案归档
- [ ] **Task 8** 全量门禁 + README 翻牌 + 提交收官
