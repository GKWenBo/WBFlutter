# M12 进阶：国际化完善 + 阿拉伯语（RTL）+ 德语

> 前置：[M12 发布与平台集成](M12-发布与平台集成.md) 搭好了 ARB + gen-l10n 的骨架，但只翻了
> 4 个 Tab 和"我的"页两行——系统切到英文，App 里 90% 的字还是中文。
>
> 本篇产出：
> - **全量抽取**：约 80 处硬编码中文 → ARB（每种语言 91 个 key），错误、订单状态、金额、日期全部本地化；
> - **四种语言**：中 / 英 / **德** / **阿**——德语练"长文本 + 格式差异"，阿语练"RTL 镜像 + 六种复数 + 数字体系"；
> - **App 内切换语言**（跟随系统 / 手选，持久化），iOS / Android 平台声明补齐；
> - **测试**：ARB 一致性、阿语复数、格式化、RTL golden、窄屏溢出冒烟（新增 45 个用例）。
>
> 为什么偏偏挑阿语和德语？它俩是国际化的"压力测试"：中英双语能藏住的问题——
> 硬编码的左右、写死的文字宽度、拼接的字符串、手搓的数字格式——加上这两种语言会一次全部暴露。
> 本篇所有"坑"都是这次改造里**真实踩到并用测试验证过的**，不是道听途说。

---

## 一、本课重点掌握（按重要程度排序）

### 1. 文案归属：谁有资格产出"给用户看的字"？⭐⭐⭐

国际化的第一步不是翻译，是**把文案从不该待的地方请出去**。改造中遇到的四种"错位"：

| 错位 | 例子（改造前） | 为什么错 | 改法 |
|---|---|---|---|
| 数据层产出文案 | `NetworkException('网络超时，请稍后重试')`，UI 里 `Text('$e')` | 数据层拿不到 BuildContext，不知道用户选了什么语言 | 数据层只给**类型 + 结构化字段**（`NetworkIssue.timeout`、状态码），UI 层 `l10n.describeError(e)` 翻译 |
| 领域模型带文案 | `enum OrderStatus { submitted('已提交') … }` | 写死的中文 label 在德语界面里只能是错的 | 枚举只留值，展示层 `status.localizedLabel(l10n)` 穷尽 switch |
| 常量里存文案 | `static const _categories = [(label: '手机', …)]` | `const` 里不可能有 context；全局缓存的翻译切语言不会变 | 常量只留 icon + slug，build 时按 slug 翻译 |
| 默认参数是文案 | `ProductGrid({this.emptyHint = '没有找到商品'})` | 默认参数必须是编译期常量 | 改成可空，`build` 里 `emptyHint ?? l10n.productsEmpty` |

`describeError` 是整个错误体系的唯一翻译点：

```dart
// core/error/error_messages.dart
extension AppErrorMessages on AppLocalizations {
  String describeError(Object error) => switch (error) {
    NetworkException(issue: NetworkIssue.timeout) => errorNetworkTimeout,
    NetworkException(issue: NetworkIssue.unreachable) => errorNoConnection,
    ServerException(:final code) => errorServer(code?.toString() ?? '?'),
    ParseException() => errorParse,
    UnknownException() => errorUnknown,
    _ => errorUnknown,   // StateError 等内部错误：它们的 message 是给开发者的中文，不能甩给德语用户
  };
}
```

- iOS 对照：≈ `Error` 只带 code/domain，`LocalizedError.errorDescription` 在展示层取本地化串。
- `AppException.message` 降级为**开发者诊断信息**（日志、断点里看），不再上屏。测试里专门断言了
  "异常诊断信息 `'断网'` 不出现在界面上"（`ui_error_paths_test.dart`）。
- 记忆钩子：**界面上的每个字，都应该能追溯到一个 ARB key。**

### 2. ARB 进阶：上下文、占位符格式、引号 ⭐⭐⭐

**① 每个 key 必须写 description（`required-resource-attributes: true`）**

英文 "Sign in" 既是登录页标题又是提交按钮。德语/阿语里两者可能译法不同——翻译人员只看到一个孤零零的
"Sign in" 是没法判断的。所以本项目**刻意拆成 `loginTitle` / `loginSubmit` 两个 key**，并让生成器强制要求
每个模板 key 都带 `@key.description`，不写直接报错。≈ `NSLocalizedString` 的 `comment` 参数，但是强制的。

**② 数字/货币/日期交给占位符格式化，别手搓**

```json
"totalAmount": "Total: {amount}",
"@totalAmount": {
  "description": "Order total in the cart / checkout bottom bar",
  "placeholders": {
    "amount": { "type": "double", "format": "simpleCurrency",
                "optionalParameters": { "name": "USD" } }
  }
}
```

| 占位符格式 | 用在 | 同一个值的不同输出 |
|---|---|---|
| `simpleCurrency` + `name: USD` | 所有金额 | en/zh `$1,234.50` · de `1.234,50 $` |
| `percentPattern`（传小数 0.085） | 折扣角标 | en `-9%` · de `-9 %` |
| `decimalPatternDigits` + `decimalDigits: 1` | 评分 | en `4.5` · de `4,5` |
| `DateTime` + `yMd+Hm` | 订单时间 | zh `2026/3/7 09:05` · de `7.3.2026 09:05` |

- **币种是业务事实，格式是语言习惯**：商品价格就是美元（DummyJSON 的数据），所以 `name: USD` 写死；
  变的只是千分位、小数点、符号位置。千万别"德语就显示欧元"——那是换算汇率，不是国际化。
- 原来的 `'\$${price.toStringAsFixed(2)}'` 在德语下会显示 `$1234.50`——德国用户会把 `.` 读成千分位。

**③ 引号、标点也属于语言**

搜索无结果的文案把引号一起放进 ARB：中文 `“手机”`、德语 `„Handy“`、阿语 `«x»`。
如果写成 `'没有找到与"$_query"相关的商品'` 再拼接，引号就被锁死在一种语言的习惯里了。

**④ 漏翻检测**

`untranslated-messages-file: build/untranslated_l10n.json`：每次生成都会输出"哪种语言缺哪些 key"。
缺 key **不会编译失败**，只会运行时悄悄回退成英文——所以本项目还写了测试拦截（见第 8 节）。

### 3. 复数：阿拉伯语的六种形式，以及 `=1` 和 `one` 的陷阱 ⭐⭐⭐

ICU/CLDR 复数类别有 6 个：`zero / one / two / few / many / other`。**每种语言用其中几个由 CLDR 规定**：

| 语言 | 用到的类别 | 说明 |
|---|---|---|
| 中文 | `other` | 没有单复数变形 |
| 英语 / 德语 | `one` `other` | 英语**没有** `zero` 类别——0 走 `other`（"0 items"），要特殊措辞必须写 `=0{…}` |
| 阿拉伯语 | 全部 6 个 | 0 / 1 / 2（双数，专门词形）/ 3–10 / 11–99 / 100+ |

```json
"orderItemCount": "{count, plural, zero{لا منتجات} one{منتج واحد} two{منتجان} few{{count} منتجات} many{{count} منتجًا} other{{count} منتج}}"
```

测试钉住的实际行为（`l10n_test.dart`）：`2 → منتجان`、`11 → 11 منتجًا`、`100 → 100 منتج`、
**`103 → 103 منتجات`（few）**——阿语规则看的是 **"除以 100 的余数"**（103 % 100 = 3），不是数值大小。

⚠️ **gen-l10n 的隐藏行为**（看生成代码验证过）：ARB 里写 `=0` / `=1` / `=2`，生成的是
`Intl.pluralLogic(zero: …, one: …, two: …)`——**和写 `zero` / `one` / `two` 编译成同一个参数**。
后果：在俄语这类 `one` 还包含 21、31、41… 的语言里，`=1{1 товар}` 会让 21 也显示成"1 товар"。
**规则：复数分支里永远用 `{count}` 占位符，不要把数字写死在译文里**（本项目英文也写的是 `=1{{count} item}`）。

### 4. RTL：一个属性都不用设，但要把"左右"改成"首尾" ⭐⭐⭐

**自动发生的事**：`MaterialApp` 的 `Localizations` 按语言自动提供 `Directionality`。切到 `ar`，
整棵树 `TextDirection.rtl`——`Row` 从右往左排、`AppBar` 返回键跑到右边、`PageView` 滑动方向反转、
`Dismissible` 的 `endToStart` 变成从左往右滑。**不需要任何 `if (isArabic)`**。

**需要你改的事**：所有写死**物理方向**的地方。

| 物理方向（不跟随语言） | 逻辑方向（跟随语言） | 本项目改了哪 |
|---|---|---|
| `EdgeInsets.fromLTRB / only(left:, right:)` | `EdgeInsetsDirectional.fromSTEB / only(start:, end:)` | `SectionHeader`（左 16 右 8，不对称） |
| `Alignment.centerRight` | `AlignmentDirectional.centerEnd` | 购物车滑动删除的垃圾桶背景 |
| `Positioned(left:, right:)` | `PositionedDirectional(start:, end:)` | （本项目的 Positioned 都是左右对称，无需改） |
| `TextAlign.left` | `TextAlign.start` | （本项目没用 left） |

- **判断规则：左右对称的不用改**（`horizontal: 16`、`fromLTRB(16, 0, 16, 12)`），**不对称的一律 Directional**。
- 购物车那个改动很典型：滑动方向跟着语言镜像了，垃圾桶图标却钉死在物理右边——阿语下滑开后露出的那一侧是空的。
- iOS 对照：`leading/trailing` vs `left/right`、`NSTextAlignment.natural`、`semanticContentAttribute`。

**图标镜像**：`Icons.chevron_right` / `arrow_back` / `arrow_forward` 在定义里带
`matchTextDirection: true`（翻 Flutter 源码 `icons.dart` 可见），RTL 下**自动翻转**，不用自己判断。
≈ `UIImage.imageFlippedForRightToLeftLayoutDirection()`。不是所有图标都该翻：时钟、播放键、对勾就不该。

**强制 LTR 的内容**：手机号、邮箱、验证码、URL "天生从左往右读"。结算页手机号输入框设了
`textDirection: TextDirection.ltr`，否则阿语下光标和对齐跑到右边。（测试断言了：三个输入框里
只有手机号是 LTR，其余跟随界面。）

### 5. 阿语的数字：显示不用管，**输入必须归一化** ⭐⭐⭐

阿语键盘默认输入**阿拉伯-印度数字** `٠١٢٣٤٥٦٧٨٩`（U+0660–0669）。它们在屏幕上是正确的数字，但：

```dart
int.tryParse('١٣٨')   // null！
```

改造前的结算页校验 `int.tryParse(phone) == null → "手机号应为 11 位数字"`——**阿语用户永远下不了单**。
这不是翻译问题，是真 bug。修法是**校验和存储前先归一化**（`core/text/normalize_digits.dart`，
同时处理波斯语/乌尔都语键盘的 U+06F0–06F9）。

- 显示侧交给 intl：本项目用的 intl 0.20.2 里，`ar` 的数字格式输出的是西式数字 `1,234.50`。
  不同 locale / intl 版本的默认数字体系可能不同——**以实际输出为准，用测试钉住**，别凭印象。
- iOS 对照：`NumberFormatter(locale: en_US_POSIX)` 解析用户输入，再按用户 locale 显示。

### 6. 德语：文字更长，按钮有法律要求 ⭐⭐

**① 长文本把布局撑爆**

德语文案普遍比英文长（常见经验值是 30% 左右，复合词能更长）。窄屏冒烟测试**真的抓到了两处 overflow**：

- `SectionHeader`：`Text + Spacer + TextButton`。"为你推荐"四个字从没出过问题，
  "Für dich empfohlen" + "Alle anzeigen" 在 320pt 宽屏上溢出。
  改成 `Expanded(Text(maxLines: 1, overflow: ellipsis))`——**Row 里长度由翻译决定的文字，必须可伸缩 + 有截断策略**。
- 结算底栏：`Row[Expanded(合计), FilledButton]`，德语按钮太长。改用 **`OverflowBar`**：
  放得下就横排（中英文和原来一模一样），放不下就竖排（合计在上、按钮在下）。
  没用 `Flexible` 平分宽度——那样中文的"合计：$1,234.50"只剩一半宽，在 375pt 屏上就会被折行，是回归。

**② 下单按钮的法定文案**

德国法律（BGB §312j，俗称"Button-Lösung"）要求在线下单按钮必须**明确表示"付费下单"**，
最典型的写法就是 **"Zahlungspflichtig bestellen"**（"有付款义务地下单"）。本项目的 `submitOrder` 德语译文用的就是它，
ARB 的 description 里也标注了"某些市场有法定措辞要求"——这类信息翻译人员必须知道。
**国际化不只是语言，还有各地的法律和习惯**（同理：结算页"手机号必须 11 位"的规则只对中国大陆成立）。

### 7. App 内切换语言 + 兜底语言 ⭐⭐⭐

**结构**（新模块 `features/settings`，跟收藏/购物车同一套模式）：

```dart
@Riverpod(keepAlive: true)
class AppLocale extends _$AppLocale {          // null = 跟随系统
  Future<Locale?> build() => ref.read(localeStorageProvider).load();
  Future<void> select(Locale? locale) => _queue.run(() async {
    await future;
    await ref.read(localeStorageProvider).save(locale);   // 保存成功才发布
    if (ref.mounted) state = AsyncData(locale);
  });
}

// app.dart
MaterialApp.router(locale: ref.watch(appLocaleProvider).asData?.value, …)
```

- **保存成功才发布**：如果写盘失败还把界面切成德语，下次启动又变回中文，用户会以为 App 抽风。
- **存语言标签字符串**（`'de'`），不存 supportedLocales 下标——和 M10 枚举存字符串是同一个道理。
- **读不出来就跟随系统**：偏好坏了或者存的语言新版本删掉了，降级成 null，绝不能拦住 App 启动。
- **语言名用"自称"**（endonym）：`简体中文 / English / Deutsch / العربية`，**不翻译**。
  手滑切到看不懂的阿语后，列表里得还写着"简体中文"才找得回来。
- **入口放两处**：我的页（菜单行）+ 登录页 AppBar——未登录的人进不了"我的"。

**兜底语言的坑（⚠️ 本篇最隐蔽的一个）**：

系统语言一个都不支持时（比如日语），MaterialApp 用 `supportedLocales` 的**第一个**。
gen-l10n 默认按**字母序**生成这个列表 → 加了阿语后变成 `[ar, de, en, zh]`——
**日语用户会看到阿拉伯语，而且整个界面镜像成从右往左**。只有中英两种时 `en` 恰好字母序第一，所以一直没暴露。

```yaml
# l10n.yaml
preferred-supported-locales: [en]   # 显式钉住兜底语言
```

（`l10n_test.dart` 有一条用例专门断言 `supportedLocales.first == en`。）

**冷启动的一帧**：偏好要异步读盘，读完之前 `locale` 是 null，第一帧按系统语言画，然后再切过去。
读 shared_preferences 只要几毫秒，通常看不出来；但窄屏测试就是在这一帧里抓到英文标题溢出的——
**这一帧也是会被布局、会出错的**。要彻底消除，可以在 `main()` 里先 await 读出偏好再 override 进 ProviderScope
（本项目为保持 main.dart 极薄没这么做）。

### 8. 平台声明：不声明，系统不知道你支持哪些语言 ⭐⭐

| 平台 | 加了什么 | 不加会怎样 |
|---|---|---|
| iOS `Info.plist` | `CFBundleLocalizations = [en, zh-Hans, de, ar]` | iOS 认为 App 只支持开发语言；"设置 → App → 语言"里也不会列出这几种 |
| Android `locales_config.xml` + `android:localeConfig` | 同样四种 | Android 13+ "按应用设置语言"列表里没有你的 App |
| Android `android:supportsRtl="true"` | — | 原生侧（系统对话框、启动页）不镜像 |

- 用户在**系统设置**里给 App 单独选的语言，会作为"系统语言"传给 Flutter——也就是 App 内"跟随系统"那个分支。两条路不冲突。
- Android 的 `configChanges` 里原本就有 `locale|layoutDirection`：切语言时 Activity 不重建，Flutter 引擎收到新语言后自己重绘。
- iOS 写 `zh-Hans`，Flutter 收到的是 `zh_Hans_CN`，按语言码回退匹配到我们的 `zh`。

### 9. 测试：让机器替你看 RTL 和长文本 ⭐⭐⭐

**① 带国际化的测试宿主**：页面都用了 `AppLocalizations.of(context)`，裸 `MaterialApp(home: Page())`
没装 delegate 会直接抛错。抽了 `test/support/localized_app.dart`，默认 `zh`（现有断言是中文），
传 `locale: Locale('ar')` 就能测 RTL。

**② ARB 一致性测试**（≈ 给翻译文件做 lint）：
- 每种语言的 key 集合与模板完全一致（缺 key 运行时才回退英文，编译期不报）；
- 每条译文都保留了模板声明的占位符（漏了 `{amount}` 能编译通过，但用户永远看不到价格）。

**③ 不可见字符**——第一次跑格式化测试时三条用例全挂，报错是这样的：

```
Expected: '1.234,50 $'
  Actual: '1.234,50 $'
   Which: is different.
```

肉眼完全一样。真相：那个"空格"是 **U+00A0 不换行空格**（CLDR 故意用它，保证金额和符号不被折到两行）；
阿语输出里还夹着 **U+200F / U+200E**（RLM/LRM 方向标记）。所以：
测试里写 `'1.234,50 \$'`；阿语只断言 `contains`；**任何代码都别去解析/比较格式化后的字符串**。

**④ DateTime 占位符的初始化坑**：单测里只 load `AppLocalizations.delegate`，调带日期占位符的方法会抛
`LocaleDataException: Locale data has not been initialized`——App 里不会遇到，因为
`GlobalMaterialLocalizations.delegate` 加载时顺手初始化了。单测要 `setUpAll(initializeDateFormatting)`。

**⑤ RTL golden**：`SectionHeader` 加了一张阿语基准图。原来两张中文 golden **一个像素都没变**
（证明 `EdgeInsetsDirectional` 在 LTR 下与原写法等价）；新图里标题在右、按钮在左。
以后谁把 padding 改回 `fromLTRB`，这张图就对不上——RTL 回归被自动拦住。

**⑥ 窄屏溢出冒烟**：`zh/de/ar × {App 外壳, 登录, 购物车, 结算}` 在 320pt 宽度下 pump。
测试环境里 overflow 会直接让用例失败，所以"能 pump 完不报错"本身就是断言。
测试字体 Ahem 每个字都是 1em 见方的方块，比真实字体宽——**在 Ahem 下不溢出，真机只会更宽松**。

**⑦ integration_test 固定语言**：它跑在真机/模拟器上，设备是英文时中文断言全挂。
用依赖注入把语言偏好换成"固定中文"，而不是去改设备语言——测试自给自足，换台设备也能跑。

---

## 二、新 API / 概念速查表

| API / 概念 | iOS 类比 | 怎么用 | 坑 |
|---|---|---|---|
| `MaterialApp.locale` | 给 App 单独设 `AppleLanguages` | 非 null 时覆盖系统语言；null 跟随系统 | 偏好异步读取时第一帧是系统语言 |
| `preferred-supported-locales` | 开发语言 / 默认本地化 | `l10n.yaml` 里 `[en]` | 不设则字母序，ar 会成为兜底语言 |
| `required-resource-attributes` | `NSLocalizedString` 的 comment | 强制模板 key 写 description | 只检查模板（en），译文 ARB 不需要 @ 元数据 |
| `untranslated-messages-file` | String Catalog 翻译进度 | 输出缺失 key 报告 | 缺 key 不报错，只回退模板语言 |
| ARB `format: simpleCurrency` | `NumberFormatter.currency` | `optionalParameters: {name: USD}` | 输出含 U+00A0；币种≠语言 |
| ARB `format: percentPattern` | `NumberFormatter.percent` | 传**小数** 0.085 | 传 8.5 会显示 850% |
| ARB `DateTime` + `yMd+Hm` | `DateFormatter.setLocalizedDateFormatFromTemplate` | 多个骨架用 `+` 连接 | 单测需 `initializeDateFormatting` |
| ICU `zero/one/two/few/many/other` | `.stringsdict` 的 NSStringPluralRuleType | 按 CLDR 写该语言需要的类别 | `=1` 与 `one` 编译成同一参数；分支里用 `{count}` |
| `Directionality` | `semanticContentAttribute` | 由 Localizations 自动提供 | 别手动包 `Directionality(rtl)` 去"模拟"阿语 |
| `EdgeInsetsDirectional` | leading / trailing 约束 | `fromSTEB(start, top, end, bottom)` | 不对称间距才需要 |
| `AlignmentDirectional` | `.leading` / `.trailing` | `centerStart` / `centerEnd` | `Alignment.centerRight` 不随语言翻转 |
| `matchTextDirection` | `imageFlippedForRightToLeftLayoutDirection` | chevron / arrow 系列图标自带 | 不是所有图标都该翻 |
| `TextField.textDirection` | `.forceLeftToRight` | 手机号/邮箱设 `TextDirection.ltr` | 不设则跟随界面方向 |
| `OverflowBar` | 自适应 axis 的 `UIStackView` | 放得下横排，放不下竖排 | 用 `overflowAlignment` 控制竖排时的对齐 |
| `Expanded` + `ellipsis` | 降低 compressionResistance | Row 里长度不定的文字 | 只用 `Spacer` 会把按钮挤出屏幕 |

---

## 三、代码地图

```
l10n.yaml                              + preferred-supported-locales / required-resource-attributes / untranslated 报告
lib/l10n/
  app_en.arb                           模板：91 个 key，每个带 description；金额/百分比/评分/日期带 format
  app_zh.arb / app_de.arb / app_ar.arb 译文（ar 的两个复数写满六种形式）
  app_localizations*.dart              gen-l10n 生成物（入库，勿手改）
lib/core/
  error/failure.dart                   message 降级为诊断信息；NetworkException 加 NetworkIssue
  error/error_messages.dart        ⭐  describeError：异常类型 → 当前语言文案（唯一翻译点）
  text/normalize_digits.dart       ⭐  阿语/波斯语数字 → ASCII
  network/request_json.dart            抛异常时带上 NetworkIssue
  widgets/error_view.dart / run_ui_action.dart   重试按钮、"操作失败"走 ARB
lib/features/settings/             ⭐  新模块：App 内语言
  data/locale_storage.dart             存语言标签字符串，读失败降级跟随系统
  data/settings_dependencies.dart      localeStorageProvider（测试替换点）
  presentation/providers/locale_providers.dart   AppLocale（AsyncNotifier + 串行 + 保存成功才发布）
  presentation/language_picker.dart    LanguageButton / LanguageMenuTile / 底部弹层 / endonym
  api.dart / ui.dart                   公开入口
lib/app/app.dart                       MaterialApp.locale ← appLocaleProvider
lib/features/orders/
  domain/order.dart                    OrderStatus 去掉中文 label
  presentation/order_status_text.dart  状态 → 文案（穷尽 switch）
  presentation/checkout_page.dart      表单本地化 + 手机号 LTR + 数字归一化 + OverflowBar 底栏
  presentation/orders_page.dart        时间/件数复数/金额走 ARB，删掉手搓的 _formatTime
lib/features/products/presentation/
  home_page.dart                       分类入口改为 slug → 翻译
  widgets/section_header.dart          EdgeInsetsDirectional + Expanded/ellipsis
  widgets/product_grid.dart            emptyHint 改可空
  product_detail_page.dart / widgets/product_card.dart   金额/折扣/评分/库存走 ARB
lib/features/cart/presentation/cart_page.dart            AlignmentDirectional.centerEnd
其余页面（login / profile / search / categories / favorites）：文案全部换成 l10n
ios/Runner/Info.plist                  CFBundleLocalizations
android/app/src/main/AndroidManifest.xml + res/xml/locales_config.xml   localeConfig + supportsRtl

测试：
  test/support/localized_app.dart      带 delegate 的测试宿主（默认 zh）
  test/l10n_test.dart                  语言清单/兜底、ARB 一致性、阿语六种复数、货币/百分比/日期、引号
  test/i18n_support_test.dart          describeError、normalizeDigits、LocaleStorage、appLocaleProvider
  test/i18n_app_test.dart              App 内切换语言端到端、窄屏 × 三语溢出冒烟、手机号 LTR
  test/golden/section_header_golden_test.dart   + 阿语 RTL 基准图
  integration_test/app_flow_test.dart  固定中文，不受设备语言影响
```

---

## 四、自测清单（都能答上来才算过关）

1. `NetworkException` 的 message 为什么不能直接上屏？数据层该给 UI 什么，才能让 UI 选对文案？
2. `OrderStatus` 原来的 `label: '已提交'` 错在哪？为什么用 switch 翻译而不是 `Map<OrderStatus, String>`？
3. 首页分类入口为什么不能再写成 `static const [(label: '手机', …)]`？`ProductGrid` 的 `emptyHint` 为什么改成可空？
4. 英文复数为什么要写 `=0{…}` 而不是 `zero{…}`？阿语 103 件商品用哪个复数形式，为什么？
5. 在俄语里写 `=1{1 товар}` 会出什么 bug？gen-l10n 的什么行为导致的？
6. 不设 `preferred-supported-locales`，日语用户打开 App 会看到什么？为什么只有中英两种时没暴露？
7. 哪些 `EdgeInsets.fromLTRB` 必须改成 Directional，哪些不用？`Icons.chevron_right` 为什么不用管？
8. 阿语用户在结算页输入手机号，改造前为什么永远过不了校验？
9. `expect(de.priceValue(1234.5), '1.234,50 $')` 为什么挂？报错信息里两边看起来一模一样。
10. 切语言时为什么要"保存成功才发布"？语言列表里的名字为什么不翻译？
11. 德语下单按钮为什么必须是 "Zahlungspflichtig bestellen"？为什么不用 `Flexible` 解决按钮太长？
12. `Info.plist` 不声明 `CFBundleLocalizations` 会怎样？用户在 iOS 设置里给 App 选的语言，怎么进到 Flutter？

---

## 五、练习

1. **繁体中文**：加 `app_zh_Hant.arb`（只需要翻 Tab），在 `Info.plist` / `locales_config.xml` 里加 `zh-Hant`，
   把 `languageEndonym` 补上"繁體中文"。思考：`LocaleStorage` 存 `toLanguageTag()` 为什么能直接支持 `zh-Hant`？
   繁体用户（系统 `zh_Hant_TW`）在你加之前看到的是什么？
2. **服务端内容**：分类名、商品名来自 DummyJSON，不在 ARB 里，切到德语依然是英文。
   给 dio 加一个拦截器，把当前语言写进 `Accept-Language` 请求头（提示：拦截器拿不到 context，
   想想怎么从 `appLocaleProvider` + 系统语言算出"实际生效的语言"）。真实后端会据此返回对应语言的内容。
3. **分类页标题快照**：首页点分类时，通过 `extra` 把**翻译后的**分类名传给分类商品页。
   在分类商品页里切换语言，标题还是旧语言——为什么？改成只传 slug、在目标页翻译。
4. **伪本地化**（pseudo-localization）：写一个脚本，把 `app_en.arb` 的每条文案变成 `[!!! Ŝîĝñ îñ !!!]`
   这种"加长 + 变音符"的版本生成 `app_xx.arb`。不用懂任何外语，就能在真机上一眼找出没走 ARB 的硬编码、以及会溢出的布局。
5. **App 显示名本地化**：桌面上的 App 名字还是 "Wan Android"。iOS 用 `InfoPlist.strings`，
   Android 用 `values-de/strings.xml`——它们不归 Flutter 管，是纯原生配置（呼应 NativeLab）。
