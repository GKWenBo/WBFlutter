# NativeLab 课程进度索引

进度的**唯一真身**在这张表；App 首页课程列表只是它的可视化副本（`lib/lessons/lesson_registry.dart` 硬编码同步）。

课程设计文档：[2026-07-06-原生交互教学课程设计.md](../2026-07-06-原生交互教学课程设计.md)

| 课时 | 主题 | 状态 |
|---|---|---|
| [L0](L0-工程创建与原生工程解剖.md) | 工程创建与原生工程解剖 | ✅ 已完成 |
| [L1](L1-MethodChannel设备信息桥.md) | MethodChannel：Flutter 调原生 | ✅ 已完成 |
| [L2](L2-数据编解码与复杂参数.md) | 数据编解码与复杂参数 | ✅ 已完成 |
| [L3](L3-EventChannel网络状态推流.md) | EventChannel：原生持续推流 | ✅ 已完成 |
| [L4](L4-页面级混合与权限.md) | 页面级混合 + 权限 | 🔵 进行中 |
| L5 | Pigeon 类型安全生成 | ⬜ 未开始 |
| L6 | PlatformView：视图级混合 | ⬜ 未开始 |
| L7 | 插件开发 | ⬜ 未开始 |
| L8 | add-to-app：原生工程接入 Flutter | ⬜ 未开始 |
| L9 | add-to-app：引擎管理与通信 | ⬜ 未开始 |

**过关条件（四项全满足才能开下一课）：**

1. 代码在 iPhone 模拟器跑通（截图验证）
2. `flutter analyze` 0 issue
3. 全量 `flutter test` 通过
4. 学员过完自测清单并口头确认
