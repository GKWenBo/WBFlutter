# L10 FFI：直接调用 C 库（nl_sign_kit）

> 企业场景：安全团队维护着一套 C 写的请求签名 SDK（HMAC-SHA256 + 设备指纹 + CRC 校验），
> iOS/Android 原生 App 都已经在用它。现在业务要上 Flutter，要求**签名结果与原生完全一致**、
> **secret 不能出现在 Dart 层**、**大文件校验不能卡 UI**。
>
> 这时 MethodChannel 不是最优解：C 库没有 Objective-C/Kotlin 包装，套一层 channel 还要
> 跨线程、编解码、手写双端桥接。Flutter 提供 **`dart:ffi`**：Dart 直接按 C ABI 调函数，
> 同步执行、零编解码。本课把这份 C SDK 封装成 **FFI 插件 `nl_sign_kit`**，并在 App 里
> 做一个可交互的 L10 演示页。

## 一、本课要掌握什么

**1. FFI 不是“另一种 channel”，它是直接调用 C 函数。**

| | MethodChannel（L1–L5） | FFI（L10） |
|---|---|---|
| 通信方式 | 二进制消息 + codec，异步 Future | 直接函数调用，按 C ABI 传参/返回 |
| 线程 | 原生 handler 跑 Platform 线程 | 在当前 isolate 的线程同步执行 |
| 代码 | 双端各写一份原生桥 | 只写一份 C（+ 可选 Swift/Kotlin 壳） |
| 类型 | `Map`/`List`/基本类型，运行期对齐 | 固定宽度 C 类型（`int32_t`/`uint64_t`/指针） |
| 适用 | 调系统能力、需要原生 UI/权限 | 复用既有 C/C++ SDK、性能敏感、要同步 |
| 代价 | 异步、编解码、双端样板 | 手动管内存、ABI/符号/链接更脆、崩溃直接带走进程 |

一句话选型：**“原生能力”走 channel，“原生算法/SDK”走 FFI**。Pigeon 解决的是 channel 的类型安全，
不是 FFI 的替代品。

**2. 本课最硬的不是 Dart 语法，而是“库怎么进包、符号怎么找到”。**

- Android：Gradle 的 `externalNativeBuild` 调 CMake/NDK，把 `libnl_sign_kit.so` 打进 APK；
  Dart 侧 `DynamicLibrary.open('libnl_sign_kit.so')`。
- iOS：C 代码随 Swift Package **静态链接**进 App；Dart 侧用 `DynamicLibrary.process()`
  从当前进程找符号。静态链接会把“没人引用”的目标文件裁掉，所以插件必须在
  `NlSignKitPlugin.register` 里调用一次 `nl_sign_kit_warmup()` 把 C 目标文件“拽”进来。

**3. 所有权模型：谁分配，谁释放。**

本课故意采用“**调用方分配输出缓冲区**”的 C API：

```c
int32_t nl_sign_kit_hmac_sha256_hex(const char *message, char *out, int32_t out_size);
```

- 入参 `message`：Dart `toNativeUtf8()` 分配 → 调用后 `malloc.free`。
- 出参 `out`：Dart `calloc<Uint8>(65)` 分配 → 原生只写 → Dart 读完 `calloc.free`。
- C 侧不保存任何 Dart 内存指针，避免“原生还拿着、Dart 已经 GC”的悬垂指针。

真实 SDK 也常见“返回 `char*`，由调用方 `xxx_free()`”的模型——**必须看文档**，
拿不准就优先选“调用方分配”，最不容易泄漏。

**4. 错误码跨 FFI 不会自动变成异常。**

C 没有异常，只有返回码。本课约定：

```c
#define NL_SIGN_KIT_OK 0
#define NL_SIGN_KIT_ERR_NOT_INITIALIZED 1001
#define NL_SIGN_KIT_ERR_INVALID_ARGUMENT 1002
#define NL_SIGN_KIT_ERR_BUFFER_TOO_SMALL 1003
#define NL_SIGN_KIT_ERR_INTERNAL 1004
```

Dart 侧每次非 0 都读 `nl_sign_kit_last_error()`，统一抛 `NlSignException(code, message)`。
页面只 catch 这一种异常，既不会把 C 的 `int` 当成功值继续跑，也不会写出宽 catch。

**5. FFI 调用会阻塞当前 isolate。**

`crc32` 对 2 MiB 只要几毫秒，留在主 isolate 没问题；但如果是 200 MiB 文件、
图像处理、音视频解码，必须：

```dart
final value = await Isolate.run(() {
  final binding = FfiSignBinding();
  return binding.crc32(bytes);
});
```

本课页面用 2 MiB 做“native vs Dart”对比，正是为了让你看到差距，同时不制造卡顿。
讲义不把 isolate 版本写进页面，是为了避免把 FFI 主线被并发细节冲散——课后练习会要求你补。

**6. 原生库的全局状态是“进程级”的。**

`nl_sign_kit_init` 把 key/secret 存在 C 静态区，多个 isolate 会共享；错误消息用
`_Thread_local` 避免串台。真实项目里密钥初始化应放在 App 启动阶段一次完成，
不要在每个页面反复 `init`。

> 演示页为什么不用 `nl_sign_kit_init(key, secret)`？为了让 **Dart 里完全不出现 secret**，
> C 库额外提供了 `nl_sign_kit_init_demo()`，密钥编译在 C 侧。真实项目当然也不该把密钥写进
> 源码，而应由原生安全存储（Keychain/Keystore）或服务端下发注入。

## 二、控件 / API 速查表

### Dart FFI（本课新东西）

| API | iOS 类比 | 用法 & 关键点 | 坑 |
|---|---|---|---|
| `DynamicLibrary.open(path)` | `dlopen` | Android 用 `libxxx.so`；iOS 动态 framework 用 `xxx.framework/xxx` | Android 只写文件名，别写绝对路径 |
| `DynamicLibrary.process()` | `dlsym(RTLD_DEFAULT, …)` | iOS 静态链接进 App 时用；先 `lookup` 探活 | Release 裁剪符号会找不到，见“坑” |
| `lookupFunction<Native, Dart>(name)` | `dlsym` + 函数指针 | Native typedef 必须和 C 头文件**逐参数一致** | 签名错了不会编译报错，运行期崩 |
| `Pointer<T>` | `UnsafeMutablePointer<T>` | `calloc<T>(n)` / `malloc<T>(n)` 分配 | `calloc` 要配对 `calloc.free` |
| `Int32` / `Uint64` | `Int32` / `UInt64` | 一律用固定宽度类型 | C 的 `long` 在不同平台宽度不同 |
| `Pointer<Utf8>` | `char *` | `toDartString()` 拷贝成 Dart String | 原生返回的静态字符串不要 free |
| `Uint8List.asTypedList()` | `UnsafeMutableBufferPointer` | 把 native 内存映射成 Dart 列表 | Dart 托管 `Uint8List` 不能直接取地址，要先拷贝 |
| `NativeCallable`（本课未用） | 函数指针回调 | 原生回调 Dart 时用 | 要管生命周期，`close()` 后不能再回调 |
| `Struct`（本课未用） | C struct | 复杂结构体用 `final class X extends Struct` | 字段顺序/对齐必须与 C 一致 |

### `package:ffi` 工具

| API | 作用 | 注意 |
|---|---|---|
| `'text'.toNativeUtf8()` | UTF-8 编码 + `malloc` | 必须 `malloc.free` |
| `ptr.toDartString()` | 拷贝成 Dart String | 不释放 native 内存 |
| `calloc<T>(n)` | 零初始化分配 | 配对 `calloc.free` |
| `malloc<T>(n)` | 分配 | 配对 `malloc.free` |

### C SDK API（`plugins/nl_sign_kit/src/nl_sign_kit.h`）

| 函数 | 作用 | 失败码 |
|---|---|---|
| `nl_sign_kit_version()` | 返回 `1.0.0` | 无 |
| `nl_sign_kit_init(key, secret)` | 保存密钥副本 | 1002（空/过长/NULL） |
| `nl_sign_kit_init_demo()` | 教学页用：密钥编译在 C 侧 | 1002 |
| `nl_sign_kit_hmac_sha256_hex(msg, out, size)` | HMAC-SHA256 → 64 hex | 1001/1002/1003 |
| `nl_sign_kit_fingerprint_hex(seed, out, size)` | FNV-1a 64 → 16 hex | 1001/1002/1003 |
| `nl_sign_kit_crc32(data, len, out)` | IEEE CRC32 | 1002 |
| `nl_sign_kit_last_error()` | 线程局部错误描述 | 返回静态指针，不要 free |
| `nl_sign_kit_warmup()` | 仅 iOS 强制链接用 | 业务不要调 |

### 构建 / 平台

| 文件 | 作用 | 关键点 |
|---|---|---|
| `src/CMakeLists.txt` | Android NDK 构建入口 | `add_library(nl_sign_kit SHARED nl_sign_kit.c)` |
| `android/build.gradle.kts` | `externalNativeBuild` | `path = file("../src/CMakeLists.txt")` |
| `ios/nl_sign_kit/Package.swift` | iOS SPM 包 | 产品名 `nl-sign-kit`（下划线换连字符） |
| `Sources/nl_sign_kit_c/nl_sign_kit_forwarder.c` | 共享 C 源码的转发 | `#include "../../../../src/nl_sign_kit.c"` |
| `Sources/nl_sign_kit/NlSignKitPlugin.swift` | 触发 C 静态链接 | `register` 里调 `nl_sign_kit_warmup()` |

## 三、代码地图

**C SDK（唯一一份源码）**
- `plugins/nl_sign_kit/src/nl_sign_kit.h` — C API、错误码、所有权约定。
- `plugins/nl_sign_kit/src/nl_sign_kit.c` — SHA-256/HMAC、FNV-1a、CRC32、状态与错误。
- `plugins/nl_sign_kit/src/CMakeLists.txt` — Android NDK 构建。

**Dart 插件层**
- `plugins/nl_sign_kit/lib/src/nl_sign_binding.dart` — `NlSignBinding` 接口、`NlSignException`、错误码枚举。
- `plugins/nl_sign_kit/lib/src/ffi_sign_binding.dart` — 平台加载、`lookupFunction`、内存分配/释放、错误映射。
- `plugins/nl_sign_kit/lib/nl_sign_kit.dart` — `NlSignKit` 门面，构造可注入 binding。

**Android**
- `plugins/nl_sign_kit/android/build.gradle.kts` — `ndkVersion` + `externalNativeBuild`。
- `plugins/nl_sign_kit/android/src/main/AndroidManifest.xml` — 空 manifest（无 Java/Kotlin 代码）。

**iOS**
- `plugins/nl_sign_kit/ios/nl_sign_kit/Package.swift` — SPM 包，C target + Swift target。
- `plugins/nl_sign_kit/ios/nl_sign_kit/Sources/nl_sign_kit_c/nl_sign_kit_forwarder.c` — 转发共享 C 源码。
- `plugins/nl_sign_kit/ios/nl_sign_kit/Sources/nl_sign_kit_c/include/nl_sign_kit_c.h` — 转发公共头。
- `plugins/nl_sign_kit/ios/nl_sign_kit/Sources/nl_sign_kit/NlSignKitPlugin.swift` — 触发链接。

**App**
- `lib/lessons/l10/order_signature.dart` — canonical payload + Dart CRC32 参考实现。
- `lib/lessons/l10/l10_ffi_sign_page.dart` — 四块演示：签名 / 指纹 / CRC / 错误码。
- `lib/lessons/lesson_registry.dart` — L10 上架。
- `test/l10_ffi_sign_test.dart` — fake binding 测 UI。
- `test/l10_native_ffi_test.dart` — 宿主编译 C，跑 RFC 4231 / CRC32 已知向量。

## 四、双端对照（Android vs iOS）

| 维度 | Android | iOS |
|---|---|---|
| 原生构建 | Gradle + CMake + NDK | Swift Package Manager + Xcode |
| 产物 | `libnl_sign_kit.so`（AAR → APK `lib/<abi>/`） | 静态链接进 App 可执行文件 |
| Dart 加载 | `DynamicLibrary.open('libnl_sign_kit.so')` | `DynamicLibrary.process()` |
| 符号可见性 | `.so` 导出符号，`dlopen` 后都能查 | 静态链接，需防止链接器裁剪；`register` 里调 `warmup` |
| 插件注册 | `ffiPlugin: true`，不需要 Kotlin 类 | `pluginClass` + `ffiPlugin`，`register` 只做“碰符号” |
| 常见坑 | NDK 版本、ABI、`.so` 没进 APK | 符号被 strip、framework 路径、Release 优化 |
| 兜底 | 检查 APK 内 `lib/<abi>/libnl_sign_kit.so` | loader 回退 `xxx.framework/xxx`；不要开 `STRIP_STYLE=all` |

**为什么 iOS 不直接 `DynamicLibrary.open` 一个 `.a`？**
静态库不是可加载的共享对象；它必须被链接进某个可执行文件/动态 framework。
本课选静态链接 + `process()`，是最贴近“集成既有静态 C SDK”的做法。
如果团队发的是 `.xcframework` 动态库，则把 `process()` 换成 `DynamicLibrary.open('xxx.framework/xxx')`。

**CocoaPods 工程怎么办？**
本工程是 SPM-only，所以只写了 `Package.swift`。CocoaPods 工程用官方 `plugin_ffi` 模板的
`ios/xxx.podspec` + `ios/Classes/xxx.c`（转发 `../../src/xxx.c`）即可，思路完全一样。

## 五、测试怎么写

FFI 没有 BinaryMessenger，`setMockMethodCallHandler` 那套用不上。测试分两层：

**1. Dart 边界注入 fake（测 UI / 错误处理 / 业务规则）**

```dart
final class _FakeBinding implements NlSignBinding {
  @override
  String hmacSha256Hex(String message) {
    if (message.isEmpty) {
      throw const NlSignException(NlSignErrorCode.invalidArgument, 'message 不能为空');
    }
    return List.filled(64, 'a').join();
  }
  // ...
}
```

页面构造 `L10FfiSignPage(kit: NlSignKit(binding: fake))`，测试就能覆盖
“签名成功”“空 payload 报 1002”“平台不支持”等分支，不需要模拟器。

**2. 宿主编译 C 源码（测算法 / 错误码）**

`test/l10_native_ffi_test.dart` 在 macOS/Linux 上用 clang 把 `src/nl_sign_kit.c`
编成临时 dylib，再用真实的 `FfiSignBinding(library: ...)` 跑：

- 未初始化 → 1001；
- `init("app-key", "Jefe")` 后 HMAC(`what do ya want for nothing?`) =
  `5bdcc146bf60754e6a042426089575c75a003f089d2739839dec58b964ec3843`（RFC 4231 Test Case 2）；
- CRC32(`123456789`) = `0xCBF43926`；
- 空 message → 1002。

这层测试能在 CI 里挡住“改 C 改坏了”的回归；模拟器验证的是“集成是否通”，两者互补。

## 六、自测清单

1. 能说清 FFI 与 MethodChannel 的三点本质差异，以及各自适用场景。
2. 能画出 Android 的 `.so` 从 `src/` 到 APK `lib/<abi>/` 的路径。
3. 能解释 iOS 为什么用 `DynamicLibrary.process()`，以及 `nl_sign_kit_warmup()` 存在的意义。
4. 能写出 `lookupFunction` 的 Native/Dart 两组 typedef，并说明签名写错的后果。
5. 能说清 `toNativeUtf8`、`calloc`、`malloc` 的配对释放关系。
6. 能解释为什么 Dart 的 `Uint8List` 要先拷进 native 内存。
7. 能说出 C 错误码如何变成 Dart 异常，以及 `last_error` 为什么要线程局部。
8. 能解释 FFI 调用阻塞 isolate，以及什么时候要 `Isolate.run`。
9. 能说出 iOS Release 下符号被裁剪的两种排查/修复方向。
10. 能独立跑通 `flutter analyze`、`flutter test`，并在模拟器/真机上验证签名结果。

## 七、课后练习

**练习 1（必做）**：把页面的 2 MiB CRC 计算移到 `Isolate.run`，比较 UI 帧率/耗时，
并说明为什么 `FfiSignBinding` 不能跨 isolate 直接传递。

**练习 2（必做）**：给 C 增加 `nl_sign_kit_base64(const uint8_t*, int32_t, char*, int32_t)`，
Dart 侧补绑定与错误码，页面加一个“Base64 编码”按钮。要求 `flutter test` 同时覆盖已知向量。

**练习 3（选做）**：把 C 的 `nl_sign_kit_init` 改成“每次调用传入 key”的无状态 API，
比较两种设计在**多 isolate、多租户、密钥轮换**下的取舍。

## 八、面试高频题（附答案）

**Q1. FFI 和 MethodChannel 的本质区别？什么时候选 FFI？**

MethodChannel 是“跨线程 + 编解码的消息传递”，异步；FFI 是“按 C ABI 直接函数调用”，同步。
选 FFI 的典型理由：已有 C/C++ SDK、需要复用同一份算法、性能敏感、需要同步返回、
想避开双端桥接样板。选 channel 的理由：系统能力、权限、原生 UI、需要异步回调。

**Q2. FFI 调用跑在哪条线程？耗时长了会怎样？**

跑在调用它的 isolate 所在线程（通常是 UI isolate 的 UI 线程）。同步调用期间 Dart 事件循环被占住，
超过一帧（约 16ms）就掉帧。长任务放 `Isolate.run` / 独立 helper isolate，native 库按进程共享，
每个 isolate 各自 `DynamicLibrary.open` 拿到的是同一个库。

**Q3. iOS 上为什么用 `DynamicLibrary.process()`？符号找不到怎么排查？**

静态链接进 App 的 C 代码不是独立 dylib，只能从当前进程的符号表里查（等价 `dlsym(RTLD_DEFAULT)`）。
排查：`nm` 看符号在不在、确认有代码引用它（本课用 `nl_sign_kit_warmup`）、
检查 Release 的 `STRIP_STYLE`/`DEAD_CODE_STRIPPING`、确认不是被 `-exported_symbols_list` 排除。
兜底是改成动态 framework + `DynamicLibrary.open('xxx.framework/xxx')`。

**Q4. Android 的 `.so` 是怎么进 APK 的？**

Gradle 的 `externalNativeBuild.cmake` 调 NDK 编译出 `.so`，AGP 把它放进 AAR 的 `jni/<abi>/`；
App 合并 AAR 后进入 APK 的 `lib/<abi>/`。运行时 `DynamicLibrary.open('libxxx.so')` 由 linker
在 App 的 native library 目录里查找。排查时先 `unzip -l app-debug.apk | grep libxxx.so`。

**Q5. FFI 的内存谁分配谁释放？**

本课采用调用方分配输出缓冲区：Dart 分配、原生写、Dart 释放。入参字符串由 Dart `toNativeUtf8`
分配并 `malloc.free`。如果 SDK 返回 `char*`，必须按文档调用它的 `free`，否则泄漏；
如果 SDK 返回内部静态缓冲区，则不能 free，也不能长期持有（下次调用可能被覆盖）。

**Q6. 为什么 C 类型要用 `int32_t`/`uint64_t`，不用 `int`/`long`？**

`int`/`long` 的宽度随平台/ABI 变化（LLP64 vs LP64），FFI 的 typedef 一旦和真实 ABI 不一致，
参数会错位、返回值被截断，甚至直接崩。固定宽度类型是跨平台 C API 的硬约定；
`size_t` 在 Dart 侧对应 `Size`，但也要注意 32/64 位差异。

**Q7. `lookupFunction` 的签名写错了会怎样？怎么避免？**

Dart 不会在编译期校验 C 符号的真实签名；写错会读到错误的内存/寄存器，轻则结果错，
重则进程崩溃。避免手段：用 `ffigen` 从头文件生成绑定、给 C API 加固定宽度类型和
`extern "C"`、写宿主机已知向量测试、在 CI 里跑。

**Q8. FFI 怎么测试？为什么 channel 的 mock 那套不适用？**

channel 测试可以在 Dart 侧挂 mock handler 模拟原生；FFI 没有消息层，mock 只能放在
Dart 封装边界（本课的 `NlSignBinding`）。算法/ABI 层要另外测：宿主机用 clang 编译 C，
`DynamicLibrary.open` 后跑已知向量；再加模拟器/真机集成验证。

## 九、本课踩坑清单（真实开发对照）

1. **iOS 静态链接裁掉 C 符号**：`DynamicLibrary.process()` 能打开、`lookup` 却报找不到。
   加一个被注册代码引用的 `warmup()` 是最小修复。
2. **Android `.so` 没进 APK**：只改了 `src/CMakeLists.txt`，忘了在 `android/build.gradle.kts`
   配 `externalNativeBuild`；或者 ABI filters 把目标 ABI 排除了。
3. **`toNativeUtf8` 忘记 free**：每次调用泄漏一小块，长跑必现。
4. **把 Dart `Uint8List` 的地址传给 C**：Dart 托管内存会移动/回收，必须拷贝到 native 内存。
5. **`int` 当 `int64_t` 用**：时间戳/文件大小被截断，签名对不上。
6. **C 返回错误码但 Dart 继续用输出缓冲**：输出可能是未初始化/半截数据，必须先判 0。
7. **在 UI isolate 跑大文件哈希**：掉帧甚至 ANR；改 isolate 或分块。
8. **Release 下才崩**：Debug 链接宽松、符号在；Release 裁剪/优化后符号没了，务必用 Release 验证一次。
