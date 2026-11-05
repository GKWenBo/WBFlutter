# nl_sign_kit

NativeLab L10 的 FFI 插件：把安全团队的 C 签名 SDK 接进 Flutter。

## 结构

```
src/                         # 唯一的 C 源码（Android / iOS 共用）
  nl_sign_kit.h
  nl_sign_kit.c
  CMakeLists.txt             # Android NDK 构建入口
android/                     # Gradle + externalNativeBuild → libnl_sign_kit.so
ios/nl_sign_kit/             # Swift Package Manager
  Package.swift
  Sources/nl_sign_kit_c/     # C forwarder（#include ../../src/nl_sign_kit.c）
  Sources/nl_sign_kit/       # NlSignKitPlugin.swift（注册时触发 C 符号链接）
lib/                         # Dart API：NlSignKit / FfiSignBinding
```

## 平台加载

- Android：`DynamicLibrary.open('libnl_sign_kit.so')`
- iOS：`DynamicLibrary.process()`（C 静态链接进 App）；失败时回退到 framework 路径
- macOS：本课不提供原生实现，调用会抛 `NlSignException(1005)`

## 测试

- App 侧 `test/l10_ffi_sign_test.dart` 用 fake binding 测 UI。
- App 侧 `test/l10_native_ffi_test.dart` 在宿主机用 clang 编译 `src/nl_sign_kit.c`，跑 RFC 4231 / CRC32 已知向量。
