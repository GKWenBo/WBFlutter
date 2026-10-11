# 架构维护验证记录

日期：2026-10-10。对应当前工作区的架构与风格优化，代码未提交、未推送。

## 最终自动检查

| 检查 | 结果 |
|---|---|
| `dart run build_runner build` | 成功，生成结果与当前源码一致 |
| `dart format --output=none --set-exit-if-changed lib test integration_test` | 122 个文件，0 项待格式化 |
| `flutter analyze --no-pub` | No issues found |
| `flutter test --no-pub` | 78 项全部通过 |
| 本地文档链接 | 55 项，0 项失效 |
| `git diff --check` | 通过 |
| lockfile / iOS 原生配置 / Golden 图片 | 未修改 |

## 已验证的行为

- 原基线：静态检查无问题，41 项单元/Widget/Golden 测试通过。
- 维护阶段完整测试：78 项通过，包含原 Golden 图片，无基准更新。
- 依赖装配：注入安全存储同时作用于登录逻辑与鉴权请求头，容器销毁关闭 Dio。
- 网络错误：服务器失败、模型结构错误、坏 JSON 和凭证读取失败分别有测试。
- 首页分页：重复触发合并、刷新隔离旧结果、失败保留列表并重试、空页终止、销毁后迟到响应。
- 本地主数据：并发加购/收藏/下单、保存失败保留原值并可继续、清空等待初始化、旧 JSON 往返。
- 结算：重复提交不重复建单、后续步骤重试不重复扣量、默认地址失败不误报下单失败，
  新单失败仍保留上一单有效检查点；新增数量以及删除后重加的同款得到保留。
- 页面：保存完成前无成功提示，提交中禁用，错误反馈，删除保存失败保留原行，刷新/登出错误处理。
- 导航：原登录门禁测试和 Tab 切换保留首页滚动位置测试通过。
- 独立只读审查：发现的坏 JSON 分类与检查点错位问题已补回归测试并修复；复查无新的重要问题。

## iOS 模拟器端到端证据

现有 `integration_test/app_flow_test.dart` 的“首页 → 商品详情 → 加入购物车”用例通过，
共 1 项。使用 iPhone 18 Pro / iOS 27.0 模拟器，Xcode 27 Release Candidate。
测试覆盖真实页面、路由与状态链路；商品/分类数据与凭证存储使用测试替代实现，
因此不代表真实后端或 Keychain 的端到端验收。

普通构建尝试失败：项目 `IPHONEOS_DEPLOYMENT_TARGET = 13.0`，本机 Xcode 27
要求至少 15.0。测试通过的运行采用临时 xcconfig 将本次构建目标覆盖为 15.0，
**项目声明的最低系统版本没有修改**。命令模式如下，临时文件仅位于本机临时目录：

```bash
# 临时 xcconfig 内容：IPHONEOS_DEPLOYMENT_TARGET = 15.0
XCODE_XCCONFIG_FILE=/private/tmp/wanshop-test.xcconfig \
  flutter test --no-pub integration_test/app_flow_test.dart -d <模拟器ID>
```

这个结果确认模拟器测试与相应构建通过，不代表默认 iOS 构建配置已经兼容 Xcode 27。
正式调整最低支持版本需要单独评估，不能为了本次重构静默减少支持范围。

## 验收边界

- 真机、Android 打包/设备验收、正式发布包、真实后端与真实安全存储未执行。
- 结算检查点只在当前应用会话有效，不提供进程重启恢复、跨键原子事务或服务端幂等保证。
- 存储插件返回成功是本项目确认边界，不声称测量了物理落盘时刻。
- 修改限制在 `Project/wan_android`；依赖版本与 lockfile 保持原样，未改动 `.workbuddy`。

## 可复现检查

```bash
dart run build_runner build
dart format --output=none --set-exit-if-changed lib test integration_test
flutter analyze --no-pub
flutter test --no-pub
git diff --check
```

文档链接检查范围为项目 README、CLAUDE.md 与 docs 下 Markdown 的本地链接；
不将公网链接检查成功或模拟器测试成功推导为真机验收通过。
