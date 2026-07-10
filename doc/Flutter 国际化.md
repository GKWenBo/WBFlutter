# Flutter 国际化（i18n）操作指南

面向 iOS 背景读者的实操手册。以 WanShop 工程（`wan_android`）的真实配置为例，讲**从零搭起、日常维护、踩坑规避**的完整流程。

> 一句话总览：**改 `.arb` → 跑 `gen-l10n` → 页面里用 `l10n.xxx`**。
> delegate、supportedLocales 第一次接好后就不用再动。

---

## 0. 数据流全景

```
lib/l10n/*.arb  ──(flutter gen-l10n)──▶  lib/l10n/app_localizations*.dart  ──▶  AppLocalizations.of(context).xxx
   翻译源(你写)          代码生成(工具)              生成的类(别手改)              页面里调用
```

iOS 对照：≈ `.strings / String Catalog`（你写）→ Xcode 生成本地化访问代码 → `NSLocalizedString` / `String(localized:)`（调用）。

**关键差别**：Flutter 这套是**类型安全**的——key 拼错**编译期就报错**，不像 `NSLocalizedString` 拼错了静默返回原字符串。

---

## 1. 加依赖 + 开开关（pubspec.yaml）

```yaml
dependencies:
  flutter_localizations:   # SDK 自带包，提供 Material/Cupertino 控件的内置翻译
    sdk: flutter
  intl: any                # ICU 消息格式（复数/日期/数字本地化），版本交给 flutter 锁定

flutter:
  generate: true           # ⭐ 关键开关：告诉构建系统"要跑 gen-l10n 代码生成"
```

> `generate: true` 不写，后面 arb 写得再对也不会生成任何代码。

---

## 2. 配置 gen-l10n（l10n.yaml，放工程根目录）

```yaml
arb-dir: lib/l10n                                 # 翻译源 *.arb 放哪个目录
template-arb-file: app_en.arb                     # 以哪个语言当"模板/权威"：key 和占位符元数据以它为准
output-localization-file: app_localizations.dart  # 生成的入口文件名
output-class: AppLocalizations                    # 生成的类名 → AppLocalizations.of(context)
nullable-getter: false                            # of(context) 返回非空，省得到处写 !
```

**"template" 的含义**：英文文件是标准。新增 key 必须先加进 `app_en.arb`（工具认它为准）；其它语言缺了这个 key 只会 warning + 回退英文，不会报错。

---

## 3. 写翻译源（.arb，本质就是 JSON）

### 模板/英文 `lib/l10n/app_en.arb`

```json
{
  "@@locale": "en",

  "navHome": "Home",
  "@navHome": { "description": "Bottom tab: products home" },

  "currentEnv": "Environment: {name}",
  "@currentEnv": {
    "description": "Shows the current build flavor",
    "placeholders": { "name": { "type": "String" } }
  },

  "cartItemCount": "{count, plural, =0{Cart is empty} =1{{count} item in cart} other{{count} items in cart}}",
  "@cartItemCount": {
    "description": "Cart summary with ICU plural",
    "placeholders": { "count": { "type": "int" } }
  }
}
```

三种 key 的写法要分清：

| 写法 | 例子 | 生成的东西 | 调用 |
|---|---|---|---|
| 纯文案 | `"navHome": "Home"` | **getter** | `l10n.navHome` |
| 带占位符 | `"currentEnv": "Environment: {name}"` | **带参方法** | `l10n.currentEnv('dev')` |
| 元数据 | `"@navHome": {...}` | 不生成代码 | 只在模板文件里写 |

> `@` 开头的是**元数据**（description / placeholders），只写在模板文件；翻译文件不用带。

### 中文 `lib/l10n/app_zh.arb`（只翻值，不带 `@` 元数据）

```json
{
  "@@locale": "zh",
  "navHome": "首页",
  "currentEnv": "当前环境：{name}",
  "cartItemCount": "{count, plural, =0{购物车是空的} other{购物车有 {count} 件商品}}"
}
```

---

## 4. 生成代码

```bash
flutter gen-l10n
```

生成三个文件（**别手改，改 arb 重新生成**）：

```
lib/l10n/app_localizations.dart      # 抽象基类 + delegate + supportedLocales
lib/l10n/app_localizations_en.dart   # 英文实现
lib/l10n/app_localizations_zh.dart   # 中文实现
```

生成物长这样：

```dart
String get navHome => 'Home';                       // 纯 getter
String currentEnv(String name) => 'Environment: $name';  // 占位符 = 字符串插值
String cartItemCount(int count) {                   // 复数走 intl 运行时逻辑
  ... intl.Intl.pluralLogic(count, ...) ...
}
```

**触发生成的三种时机**（不用每次手敲）：`flutter gen-l10n`（显式）、`flutter pub get`、`flutter run` / `flutter build`——后三者在 `generate: true` 时都会自动跑一遍。

> 生成物**入库**（和 `.g.dart` 一样提交进 git），免得别人 clone 后没跑生成就编译不过。

---

## 5. 接进 MaterialApp（只两行）

```dart
return MaterialApp.router(
  localizationsDelegates: AppLocalizations.localizationsDelegates, // 我们的 + flutter 内置三件套
  supportedLocales: AppLocalizations.supportedLocales,            // 从 arb 自动推出 [en, zh]
  // ...
);
```

- `localizationsDelegates` 里的"内置三件套"= `GlobalMaterialLocalizations / GlobalWidgetsLocalizations / GlobalCupertinoLocalizations`，负责**框架自带控件**的文案（日期选择器的"取消/确定"、下拉刷新提示等）。`AppLocalizations.localizationsDelegates` 已经帮你合好了，所以只写一行。
- **语言怎么定**：系统语言命中 `supportedLocales` 里哪个就用哪个；都不命中用列表第一个（这里 en）。跟随系统，用户不用手选。

---

## 6. 页面里用

```dart
final l10n = AppLocalizations.of(context);   // 从最近的 Localizations 拿当前语言实例

Text(l10n.navHome)                 // 纯文案
Text(l10n.currentEnv('dev'))       // 占位符 → "当前环境：dev"
Text(l10n.cartItemCount(count))    // 复数 → count=0 "购物车是空的"，count=3 "购物车有 3 件商品"
```

> `of(context)` 依赖 context 在 `MaterialApp` 之下（拿得到 Localizations）。页面在路由树里天然满足。

---

## 7. 日常维护

### A. 加一条新文案

1. 先在**模板** `app_en.arb` 加：`"checkoutSubmit": "Place Order"`
2. 各语言文件补：`app_zh.arb` 加 `"checkoutSubmit": "提交订单"`
3. `flutter gen-l10n`（或直接 `flutter run`）
4. 页面里 `l10n.checkoutSubmit`——拼错编译期就红

### B. 加一门新语言（比如日语）

1. 新建 `lib/l10n/app_ja.arb`，首行 `"@@locale": "ja"`，把 key 翻一遍
2. 重新生成——`supportedLocales` 会**自动**多出 `ja`，一行代码不用改
3. 系统语言切日语即可看到

---

## 8. 复数 & 占位符（ICU MessageFormat）

```
{count, plural, =0{...} =1{...} other{...}}
        └─变量  └─类别  └── 各分支文案，里面还能再插 {count}
```

- **英文**要写 `=1{item}` 和 `other{items}`（有单复数变形）；**中文**没有变形，只需 `=0` 和 `other`。
- `other` 是**必填兜底**，缺了生成会报错。
- 占位符要在模板的 `@key.placeholders` 里声明 `type`（`int` / `String` / `DateTime` …）。
- `DateTime` 还能配 `"format": "yMMMd"` 做本地化日期，≈ iOS 的 `DateFormatter`。

iOS 对照：ICU 复数 ≈ `.stringsdict`，但写在**同一个 arb 键**里，不用单独文件。

---

## 9. 测试里切换语言

Tab 标签等文案一旦国际化，**widget 测试受默认语言影响**：`flutter test` 默认 `en`，原来断言中文 `'首页'` 的测试会挂。正确姿势是**在测试里强制设备语言**：

```dart
tester.platformDispatcher.localesTestValue = const [Locale('zh')];
addTearDown(tester.platformDispatcher.clearLocalesTestValue);
```

- ⚠️ 要用 **`localesTestValue`（复数）** 而不是 `localeTestValue`（单数）——MaterialApp 的 locale 解析读的是 `platformDispatcher.locales`（列表）。单数那个设了不生效。
- iOS 对照：≈ XCUITest 用 `launchArguments = ["-AppleLanguages", "(zh-Hans)"]` 测指定语言界面。

也可以直接 load 某语言实例做纯单测（不 pump 整个 App）：

```dart
final zh = await AppLocalizations.delegate.load(const Locale('zh'));
expect(zh.navHome, '首页');
expect(zh.cartItemCount(0), '购物车是空的');
```

---

## 10. 常见坑速查

| 坑 | 现象 | 解法 |
|---|---|---|
| 忘了 `generate: true` | arb 写对了但没生成任何类 | pubspec 里补开关 |
| 改了 arb 没重新生成 | 界面文案不变 | `flutter gen-l10n` 或重跑 |
| 测试默认语言是 en | 断言中文的 widget 测试挂 | `platformDispatcher.localesTestValue = [Locale('zh')]`（**复数**） |
| 占位符没声明 type | 参数类型变成 `Object` | `@key` 里补 `placeholders.xxx.type` |
| 手改了生成的 `.dart` | 下次生成被覆盖 | 只改 `.arb`，生成物入库但不手编辑 |
| `.arb` 是 JSON | 多逗号/漏引号 → 生成失败 | 当普通 JSON 校验 |
| `other` 分支漏写 | 复数生成报错 | plural 必须有 `other` 兜底 |

---

## 附：iOS ↔ Flutter 概念对照

| Flutter | iOS |
|---|---|
| `.arb` 文件 | `.strings` / String Catalog |
| `flutter gen-l10n` | Xcode 从字符串目录生成访问代码 |
| `AppLocalizations.of(context).key` | `NSLocalizedString` / `String(localized:)`（但类型安全） |
| ICU `{n, plural, ...}` | `.stringsdict` |
| `supportedLocales` | 工程里勾选的 Localizations 语言集合 |
| 内置三件套 delegate | 系统控件自带的多语言 |
| `localesTestValue` | XCUITest `-AppleLanguages` |
