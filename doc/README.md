# WBFlutter 技术文档索引

面向 **iOS 转 Flutter** 的深度技术笔记。与仓库里三条学习线（`wan_android` / `native_lab` / `state_lab`）的课程讲义是**互补关系**：

- **课程讲义**（`*/docs/lessons/`、`state_lab/docs/tech/`）——跟着做、讲 API 与工程用法
- **本目录**——讲原理与机制，回答"它为什么这样设计"，主要服务于面试深挖

---

## 一、状态管理原理

从 Provider 的局限出发，理解 Riverpod 的设计动机。**建议按顺序读**：

| 文档 | 一句话 | 面试考点 |
| --- | --- | --- |
| [Provider 实现原理](Provider实现原理.md) | InheritedWidget 的语法糖 + ChangeNotifier 的监听桥接 | `_inheritedElements` 哈希表 O(1) 查找、`notifyListeners` → rebuild 完整链路、read/watch/select 底层差异 |
| [Riverpod 实现原理](Riverpod实现原理.md) | 把依赖图搬出 Widget 树，自建平行运行时 | Provider ≠ 全局状态、DAG 建图与惰性传播、autoDispose 引用计数、3.x 变化 |

> 📎 配套 API 实践：[state_lab S1 地基](../state_lab/docs/tech/s1-状态管理的地基.md) → [S2 Provider](../state_lab/docs/tech/s2-provider.md) → [S6 Riverpod](../state_lab/docs/tech/s6-riverpod.md) → [S5 横向选型](../state_lab/docs/tech/s5-横向对比与选型.md)

---

## 二、测试

| 文档 | 一句话 | 适用场景 |
| --- | --- | --- |
| [Flutter 测试体系](Flutter测试体系.md) | 单元 / Widget / Golden / 集成 / E2E 五层全景 + CI 策略 | 建测试体系、定覆盖率门槛、选工具 |
| [Mocktail 使用指南](Mocktail使用指南.md) | 零代码生成 Mock 的 API 与陷阱 | 写具体的 mock 用例 |

> 📎 配套工程实践：[WanShop M11 · 测试](../wan_android/docs/lessons/M11-测试.md)

---

## 三、工程化与发布

| 文档 | 一句话 | 什么时候需要 |
| --- | --- | --- |
| [Flutter 多环境打包配置](Flutter多环境打包配置.md) | `--flavor` + `--dart-define` 双端配置，dev/staging/prod 并存 | 要真·多渠道包时；只切 baseUrl 用 `--dart-define` 就够 |
| [Flutter 国际化](Flutter国际化.md) | `.arb` → `gen-l10n` → `l10n.xxx` 全流程 | 接多语言、写受语言影响的 widget 测试 |

> 📎 配套工程实践：[WanShop M12 · 发布与平台集成](../wan_android/docs/lessons/M12-发布与平台集成.md)

---

## 四、原生交互

原生交互专题的完整内容在 **[NativeLab 课程讲义](../native_lab/docs/lessons/README.md)**（L0–L9，含 MethodChannel / EventChannel / Pigeon / PlatformView / 插件开发 / add-to-app），本目录不重复收录。

面试速查见 [Flutter 与原生交互面试总纲](../native_lab/docs/lessons/面试总纲-Flutter与原生交互.md)。

---

## 文档约定

- **代码块里标注为"源码"的内容均为示意性伪代码**，用于说明机制，字段名与真实包内实现不完全一致。
- 每篇开头的引用块标明**适用版本**与**前置/配套阅读**。
- ⚠️ 标记 = 高频陷阱或容易踩的坑；⭐ 标记 = 面试重点或关键约束。
- 文件命名：中文、无空格。新增文档请同步更新本索引。
