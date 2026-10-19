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

---

# 国际化完善验证记录（M12 进阶）

日期：2026-10-19。全量文案抽取 + 阿拉伯语（RTL）/ 德语 + App 内切换语言；代码未提交、未推送。

## 自动检查

| 检查 | 结果 |
|---|---|
| `dart run build_runner build` | 0 项输出变化，`.g.dart` 与源码一致 |
| `flutter gen-l10n` | 重新生成后与入库生成物逐字节一致；未翻译报告为 `{}` |
| `dart format --output=none --set-exit-if-changed lib test integration_test` | 139 个文件，0 项待格式化 |
| `flutter analyze --no-pub` | No issues found |
| `flutter test --no-pub` | 142 项全部通过（原 87 项 + 新增 55 项，含代码审查后的 10 项回归测试） |
| Golden | 原两张 `section_header` 基准图未更新且通过；新增 `section_header_with_more_rtl.png` |
| 本地文档链接 | 62 项，0 项失效 |
| `git diff --check` | 通过 |

## 已验证的行为

- ARB：四种语言各 93 个 key，key 集合与占位符与模板一致；`supportedLocales.first == en`。
- 复数：阿语 0/1/2/3/10/11/99/100/103 分别落入 zero/one/two/few/few/many/many/other/few。
- 格式：en/zh/de/ar 的金额、百分比、一位小数、日期输出；德语分隔为 U+00A0。
- 错误：异常按类型翻译，内部错误不泄露中文诊断信息（含页面级断言）。
- 语言偏好：读写往返、跟随系统、已移除语言与读取失败降级、保存成功才发布、保存失败保留原语言。
- App：冷启动恢复德语、切阿语后文案与 `TextDirection.rtl` 生效、切回跟随系统恢复中文。
- 窄屏（320pt）：zh/de/ar × App 外壳/登录/购物车/结算无溢出；阿语手机号输入框为 LTR。
- 窄屏测试曾抓到两处真实溢出（`SectionHeader` 标题、结算底栏按钮），已修复并由该测试守护。
- 阿语数字归一化：`١٣٨…` / `۱۳۸` 可通过手机号校验并以 ASCII 存储。

## 代码审查后的修复（7 条意见，6 条成立）

| 意见 | 结论 | 回归测试 |
|---|---|---|
| 语言弹层保存中连点会 pop 掉下层页面 | 修复（保存中禁用，只 pop 一次） | `i18n_app_test` 连点用例 |
| 结算"购物车为空"等原因被兜成通用文案 | 修复（`CheckoutException` + `LocalizedException`） | `checkout_reliability_test`、`i18n_support_test` |
| 阿语折扣负号显示到数字右侧 | 修复（传负数，ARB 不写 `-`） | `l10n_test` 断言负号前有 U+200E |
| 冷启动首帧先按系统语言渲染 | 修复（`deferFirstFrame`） | `i18n_app_test` 断言读盘前 `sendFramesToEngine == false` |
| 分类标题以翻译快照经 `extra` 传递 | 修复（按 slug 在 build 时翻译） | `i18n_app_test` 分类标题用例 |
| 手机号框 LTR 会把标签/图标翻到左侧 | **误报**：`textDirection` 只传给 EditableText，实测三个图标 x 相同 | 测量写入 `i18n_app_test` |
| 登录密码错误显示为服务器错误（400） | 修复（登录路径 400/401 → `InvalidCredentialsException`） | `i18n_support_test`（含 `/auth/me` 401 不误判） |

- 变异检查：分别删除防连点、`deferFirstFrame`、按 slug 翻译三处修复，对应用例均变红；还原后全部通过。
- 新增测试另抓到一处：语言弹层在 800×600 画布溢出 23px，已改为可滚动。
- 自查：`describeError` 原注释声称 sealed 可保证编译期穷尽，但被 `_` 分支架空；已拆为无默认分支的内层 switch。

## iOS 模拟器观察（非完整验收）

iPhone 18 Pro / iOS 27.0，Xcode 27 RC。构建同样需要把部署目标临时覆盖为 15.0
（命令行 `IPHONEOS_DEPLOYMENT_TARGET=15.0`，arm64-only，**项目声明未修改**）。

- 跟随系统（中文）：首页、登录页文案正常，登录页 AppBar 出现语言按钮。
- 以 `-AppleLanguages (ar)` 启动：首页整体镜像（Tab 顺序、搜索框、分类入口、`SectionHeader`、
  Banner 指示点、DEV 角标位置），真实字体下阿语渲染正常。
- **未完成**：该模拟器同时被另一个工作流使用（日志显示 `com.wenbo.WBLocalization` 经
  CoreSimulatorBridge 被外部启动），为避免干扰，未在模拟器上操作语言弹层、未跑
  `integration_test`；商品接口在模拟器内请求失败（显示通用错误文案），未能目测金额格式。
  App 内切换语言的端到端链路由 Widget 测试覆盖。

## 验收边界

- 译文由开发者撰写，未经母语者审校；德语下单按钮采用 "Zahlungspflichtig bestellen"，未做法律审核。
- 服务端内容（分类名、商品名）仍为接口原文，未实现 `Accept-Language`。
- App 显示名（`CFBundleDisplayName` / `android:label`）未本地化；未加入繁体中文。
- Android 未构建验证（`localeConfig` / `supportsRtl` 仅完成配置）。
- `integration_test/app_flow_test.dart` 已固定为中文，但本轮未在设备上运行；
  在 `flutter-tester` 无头环境下它因 sqflite 插件缺失失败，HEAD 版本同样失败，属既有限制。
