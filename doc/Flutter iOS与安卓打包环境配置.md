# Flutter iOS / Android 多环境打包配置指南

面向 iOS 背景读者的实操手册。目标：**一套代码打出 dev / staging / prod 三种包，两端配置保持同步**。以 WanShop 工程（`wan_android`）真实包名为例。

> 本工程当前的真实身份：
> - Android `applicationId = com.wenbo.wan_android`
> - iOS `PRODUCT_BUNDLE_IDENTIFIER = com.wenbo.wanAndroid`
>
> 本文是"**要真·多渠道包时怎么做**"的参考。日常本地开发用 M12 的 `--dart-define` 就够了，不需要动原生工程。

---

## 0. 先分清两层（关键，别一上来就配原生）

| 你想按环境区分的东西 | 用哪套机制 | 要不要动原生工程 |
|---|---|---|
| API 域名 / 功能开关 / 日志 / 界面水印 | `--dart-define=FLAVOR=xxx`（M12 已做） | ❌ 不用，纯 Dart |
| **Bundle Id / applicationId**（三套包并存于一台机） | `--flavor` + 原生 flavor | ✅ 要 |
| **App 名字 / 图标** | `--flavor` + 原生资源 | ✅ 要 |
| **签名 / 描述文件 / 各环境 Firebase 配置** | 原生 flavor | ✅ 要 |

一句话：**只要"手机上那个 App 本身"要长得不一样（名字/图标/能并排装），就必须动原生。** 否则别碰。

`--flavor` 和 `--dart-define` 是**两件事、配合用**：
- `--flavor prod` → 决定**原生身份**（bundle id、图标、签名）
- `--dart-define=FLAVOR=prod` → 决定 **Dart 逻辑**（baseUrl、日志、AppEnv）

打包时两个一起传：

```bash
flutter build appbundle --flavor prod --dart-define=FLAVOR=prod
flutter build ipa       --flavor prod --dart-define=FLAVOR=prod
```

---

## 1. 命名约定：三处名字必须一模一样 ⭐

这是双端同步的**唯一硬约束**。flavor 名（这里用 `dev / staging / prod`）必须在三个地方**完全一致**：

```
flutter build --flavor prod          ← 命令
       │
       ├── Android: build.gradle.kts 里 productFlavors { prod { } }
       └── iOS:     Xcode 里名为 "prod" 的 Scheme
```

名字对不上，Flutter 会报"找不到 flavor / scheme"。建议三套：`dev`（本地）、`staging`（预发）、`prod`（生产）。

约定好的 id 后缀方案（推荐 prod 用裸 id，其余加后缀，方便并存）：

| flavor | Android applicationId | iOS Bundle Id | App 显示名 |
|---|---|---|---|
| dev | `com.wenbo.wan_android.dev` | `com.wenbo.wanAndroid.dev` | WanShop Dev |
| staging | `com.wenbo.wan_android.stg` | `com.wenbo.wanAndroid.stg` | WanShop Stg |
| prod | `com.wenbo.wan_android` | `com.wenbo.wanAndroid` | WanShop |

---

## 2. Android 侧完整配置

### 2.1 声明 productFlavors（`android/app/build.gradle.kts`）

```kotlin
android {
    namespace = "com.wenbo.wan_android"
    // ...

    flavorDimensions += "env"                 // 维度名，随便取；单维度够用
    productFlavors {
        create("dev") {
            dimension = "env"
            applicationIdSuffix = ".dev"       // → com.wenbo.wan_android.dev
            resValue("string", "app_name", "WanShop Dev")
        }
        create("staging") {
            dimension = "env"
            applicationIdSuffix = ".stg"
            resValue("string", "app_name", "WanShop Stg")
        }
        create("prod") {
            dimension = "env"
            // 不加后缀 → 裸 applicationId
            resValue("string", "app_name", "WanShop")
        }
    }
}
```

### 2.2 让 App 名字跟着 flavor 走

把 `android/app/src/main/AndroidManifest.xml` 里的 `android:label` 改成引用资源：

```xml
<application
    android:label="@string/app_name"   <!-- 原来可能是写死的 "wan_android" -->
    ... >
```

`resValue` 会给每个 flavor 生成对应的 `app_name` 字符串，装到手机上名字就区分开了。

### 2.3 每个 flavor 的图标 / 配置文件

按 flavor 建资源目录，Gradle 会自动**覆盖** `main/` 里的同名文件：

```
android/app/src/
  main/        # 公共
  dev/res/mipmap-*/ic_launcher.png       # dev 专属图标
  dev/google-services.json               # dev 的 Firebase（若用）
  prod/res/mipmap-*/ic_launcher.png
  prod/google-services.json
```

### 2.4 发布签名（keystore）⭐

> ⚠️ keystore 和密码**绝不入库**。本工程 `android/.gitignore` 已忽略 `key.properties` / `*.jks` / `*.keystore`。

**① 生成 keystore（你在本机跑，密码自己保管）：**

```bash
keytool -genkey -v -keystore ~/wanshop-release.jks \
  -keyalg RSA -keysize 2048 -validity 10000 -alias wanshop
```

**② 写 `android/key.properties`（不入库）：**

```properties
storeFile=/Users/wenbo/wanshop-release.jks
storePassword=你的store密码
keyPassword=你的key密码
keyAlias=wanshop
```

**③ 在 `build.gradle.kts` 里读取并接线：**

```kotlin
import java.util.Properties
import java.io.FileInputStream

val keyProps = Properties().apply {
    val f = rootProject.file("key.properties")
    if (f.exists()) load(FileInputStream(f))
}

android {
    signingConfigs {
        create("release") {
            keyAlias = keyProps["keyAlias"] as String?
            keyPassword = keyProps["keyPassword"] as String?
            storeFile = (keyProps["storeFile"] as String?)?.let { file(it) }
            storePassword = keyProps["storePassword"] as String?
        }
    }
    buildTypes {
        getByName("release") {
            signingConfig = signingConfigs.getByName("release")  // 原来是 debug，改成 release
        }
    }
}
```

### 2.5 出包

```bash
flutter build appbundle --flavor prod --dart-define=FLAVOR=prod   # 上架 Google Play 用 .aab
flutter build apk       --flavor dev  --dart-define=FLAVOR=dev    # 内部分发用 .apk
# 产物：build/app/outputs/bundle/prodRelease/  或  flutter-apk/
```

---

## 3. iOS 侧完整配置

iOS 没有"product flavor"概念，用 **Build Configuration + Scheme + .xcconfig** 拼出同样效果。这套在 Xcode GUI 里做最稳（命令行改 pbxproj 易错）。

### 3.1 建 Build Configurations

Xcode → 选中 **Runner 项目**（不是 Target）→ Info → Configurations。默认有 `Debug / Release / Profile`。给每个 flavor 各复制一套：

```
Debug-dev    Release-dev    Profile-dev
Debug-stg    Release-stg    Profile-stg
Debug-prod   Release-prod   Profile-prod
```

（共 9 个。Flutter 要求配置名里带上环境标识。）

### 3.2 建 Scheme（名字 = flavor）

Xcode → Product → Scheme → Manage Schemes → 新建三个 Scheme：`dev` / `staging` / `prod`（**名字必须和 `--flavor` 一致**）。每个 Scheme 编辑：

| Scheme 动作 | 绑定的 Configuration |
|---|---|
| Run | `Debug-<flavor>` |
| Profile | `Profile-<flavor>` |
| Archive | `Release-<flavor>` |

**记得勾 "Shared"**，否则 Flutter / CI 看不到这个 scheme。

### 3.3 用 .xcconfig 按环境注入身份

在 `ios/Flutter/` 下建每套环境的 xcconfig（举例 `dev.xcconfig`）：

```
#include "Generated.xcconfig"     // Flutter 生成的，必须 include
PRODUCT_BUNDLE_IDENTIFIER = com.wenbo.wanAndroid.dev
DISPLAY_NAME = WanShop Dev
ASSETCATALOG_COMPILER_APPICON_NAME = AppIcon-dev
```

然后把每个 Build Configuration 关联到对应 xcconfig（项目 Info → Configurations 里选文件）。

`Info.plist` 里改成引用变量：

```xml
<key>CFBundleDisplayName</key>
<string>$(DISPLAY_NAME)</string>
```

### 3.4 App 图标 per flavor

`Assets.xcassets` 里建多个图标集：`AppIcon-dev` / `AppIcon-stg` / `AppIcon`，用上面的 `ASSETCATALOG_COMPILER_APPICON_NAME` 按配置切换。

### 3.5 签名与描述文件

- **签名不是我能代做的**（涉及证书/私钥/账号）——你在 Xcode → Target → Signing & Capabilities 里，**逐个 Configuration** 选对应的 Team / Bundle Id / Provisioning Profile。
- 每套 bundle id（.dev/.stg/裸）在 Apple Developer 后台要有各自的 App ID 和描述文件。
- 各环境的 `GoogleService-Info.plist`（若用 Firebase）：放不同目录，加一个 Run Script Build Phase 按 `${CONFIGURATION}` 拷贝对应文件到 bundle。

### 3.6 出包

```bash
flutter build ipa --flavor prod --dart-define=FLAVOR=prod
# 产物 build/ios/ipa/*.ipa；或 Xcode Organizer 里 Archive 上传
```

---

## 4. 双端概念对照表

| Flutter | Android | iOS |
|---|---|---|
| `--flavor prod` | `productFlavors { prod }` | Scheme `prod` |
| 环境后缀 | `applicationIdSuffix = ".dev"` | `.xcconfig` 里 `PRODUCT_BUNDLE_IDENTIFIER` |
| App 名 | `resValue("string","app_name",…)` | `.xcconfig` `DISPLAY_NAME` → Info.plist |
| 图标 | `src/<flavor>/res/mipmap` | `ASSETCATALOG_COMPILER_APPICON_NAME` |
| 环境配置文件 | `src/<flavor>/google-services.json` | Run Script 拷 `GoogleService-Info.plist` |
| 签名 | `signingConfigs` + `key.properties` | Xcode Signing per Configuration |
| 打包产物 | `.aab` / `.apk` | `.ipa` |

---

## 5. 与 M12 的 AppEnv 配合

原生 flavor 只管"包的身份"，**Dart 层的 baseUrl/日志还是 M12 的 `AppEnv` 在管**。所以打包脚本里两个参数要**成对出现且一致**：

```bash
# ✅ 对：原生身份 prod + Dart 逻辑 prod
flutter build ipa --flavor prod --dart-define=FLAVOR=prod

# ❌ 错：装的是 prod 包，但连的是 dev 后端——最危险的事故
flutter build ipa --flavor prod --dart-define=FLAVOR=dev
```

> 建议：写个 `Makefile` / shell 脚本把 flavor 和 dart-define 绑死，人手别分开传。

---

## 6. 本机环境注意（国内网络）

- **首次原生构建会拉大依赖**，本机 7890 代理对大文件不稳。相关镜像/JDK/Gradle 配置见记忆与 `android/` 下的 gradle 配置；命令行构建建议 `env -u HTTP_PROXY -u HTTPS_PROXY` 跑。
- **iOS 模拟器 release 构建有 lipo 坑**：`flutter build ios --simulator` 可能秒挂；真机 Archive 正常，或调试用 `flutter run`。
- **keystore / key.properties / 证书私钥永不入库**（已 gitignore）。团队协作用 CI 的加密 secret 注入。

---

## 7. 上架前检查清单

- [ ] flavor 名在 `--flavor` / Android productFlavor / iOS scheme 三处完全一致
- [ ] 三套 bundle id / applicationId 各不相同且和后台 App ID 对应
- [ ] `--flavor` 与 `--dart-define=FLAVOR` **成对且一致**（别把 prod 包连到 dev 后端）
- [ ] release 用的是**正式 keystore / 描述文件**，不是 debug 签名
- [ ] App 名字、图标按环境区分（能并排安装、一眼分得清）
- [ ] `key.properties` / `*.jks` / 证书 不在 git 里
- [ ] 版本号 `version: x.y.z+build`（pubspec）已递增
- [ ] `flutter build appbundle` / `flutter build ipa` 都能出包

---

## 附：只想要"环境开关"、不想碰原生？

那就别配本文这套。保持 M12 的 `--dart-define=FLAVOR=xxx` 即可——同一个包、同一个图标，只切 baseUrl/日志/水印。**iOS/Android 工程一行都不用改。** 等真有"多套并存包 / 上架多环境"的需求了，再回来照本文配。
