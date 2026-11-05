// SwiftPM 的 target 必须是包内目录，而 C 源码只有一份（插件根目录 src/）。
// 这里用官方 plugin_ffi 模板同款做法：放一个 forwarder，把包外源码 include 进来。
//
// 目录：plugins/nl_sign_kit/ios/nl_sign_kit/Sources/nl_sign_kit_c/
// 往上 4 级 = plugins/nl_sign_kit/
#include "../../../../src/nl_sign_kit.c"
