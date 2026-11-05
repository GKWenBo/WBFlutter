// SwiftPM 在编译 C target 时需要一份 public header 生成 module map。
// 真正的声明在插件根目录 src/nl_sign_kit.h，这里只做转发（不复制声明，避免漂移）。
//
// 目录：plugins/nl_sign_kit/ios/nl_sign_kit/Sources/nl_sign_kit_c/include/
// 往上 5 级 = plugins/nl_sign_kit/
#ifndef NL_SIGN_KIT_C_FORWARDER_H
#define NL_SIGN_KIT_C_FORWARDER_H

#include "../../../../../src/nl_sign_kit.h"

#endif /* NL_SIGN_KIT_C_FORWARDER_H */
