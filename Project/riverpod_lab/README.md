# Riverpod Lab

「一个用法一个页面」的 Riverpod 3.x 教学工程：每个示例都能跑起来对照，代码带注释，配套文档讲清「为什么」和「哪里会踩坑」。

- **版本基线**：Flutter 3.44 / Dart 3.12 / riverpod 3.4.3 / riverpod_generator 4.x
- **写法**：全部使用官方推荐的 codegen（`@riverpod` 注解），与生产项目一致
- **原理深挖**：[doc/Riverpod实现原理.md](../../doc/Riverpod实现原理.md)（本工程只讲「怎么用」）

## 快速开始

```bash
cd Project/riverpod_lab
flutter pub get
dart run build_runner build   # 生成 lib/**/*.g.dart；改了 @riverpod 就要重跑
flutter run                   # 设备列表里选 Android 真机
```

## 课程表

| 课 | 示例 | 学到什么 | 文档 | 状态 |
| --- | --- | --- | --- | --- |
| S1 | 计数器 | `Notifier` 读写状态、`ConsumerWidget`、`select` 精确订阅 | [01-counter.md](docs/01-counter.md) | 待实现 |
| S2 | 待办清单 | 不可变状态、派生 provider、`ref.listen` 处理副作用 | [02-todo.md](docs/02-todo.md) | 待实现 |
| S3 | 异步三态 | `AsyncNotifier`、`AsyncValue`、dio 数据层、刷新与重试 | [03-async.md](docs/03-async.md) | 待实现 |
| S4 | 搜索与生命周期 | `family` 参数化、`autoDispose`、防抖搜索、`keepAlive` | [04-family-lifecycle.md](docs/04-family-lifecycle.md) | 待实现 |
| S5 | 依赖注入与测试 | 仓库抽象、`overrides` 注入 Fake、shared_preferences、单测 | [05-di-testing.md](docs/05-di-testing.md) | 待实现 |

每课对应仓库里一次独立提交，方便你按课回看 diff。

## 目录结构

```
lib/
├── main.dart                 # ProviderScope 入口
├── app.dart                  # MaterialApp
├── features/                 # 按功能组织，每课一个目录
│   ├── home/                 # 课程目录（demos 列表在这里登记）
│   └── ...                   # s1 counter / s2 todo / s3 async / s4 search / s5 settings
└── shared/                   # 跨课复用的少量基础设施
docs/
├── 00-学习路线.md
├── 01-counter.md ... 05-di-testing.md
└── 99-踩坑清单.md
test/                         # provider 单测 + widget 测试
```

## 约定

- **状态与 UI 分离**：页面只负责展示和交互，provider 声明放在同目录的 `*_provider.dart` 里。
- **provider 只通过 `@riverpod` 声明**，不混用手写 `NotifierProvider`（两种风格并存会干扰理解）。
- **`.g.dart` 一并提交**：生成物就是最好的教材，可以直接读它看注解被翻译成了什么；生产里提交与否都常见。
- **数据层依赖按课引入**：S3 引入 `dio`，S5 引入 `shared_preferences`，避免一开始堆依赖。
