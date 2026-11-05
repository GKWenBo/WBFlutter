/*
 * nl_sign_kit：安全团队的 C 签名 SDK（教学版）。
 *
 * 真实项目里这类库通常由安全团队维护、以 .a/.so/.xcframework 形式分发；
 * 这里用一份自包含的实现，方便 Android 与 iOS 共用同一份 C 源码。
 *
 * ★ 生产环境请使用 BoringSSL / OpenSSL 等经过审计的密码学库，
 *   本文件的 SHA-256/HMAC 只为教学，不要直接用于真实资金链路。
 *
 * ABI 约定：
 *   - 所有返回值是 int32_t 错误码，0 = 成功；错误详情用 nl_sign_kit_last_error() 取。
 *   - 输出字符串由【调用方】分配缓冲区，本库只写不持有 —— 谁分配谁释放，
 *     这是 C 接口里最不容易扯皮的一种所有权模型。
 *   - 字符串一律 UTF-8、以 '\0' 结尾；SIZE 参数包含 '\0'。
 */
#ifndef NL_SIGN_KIT_H
#define NL_SIGN_KIT_H

#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

/* 错误码。Dart 侧 NlSignErrorCode 与这里逐值对应。 */
#define NL_SIGN_KIT_OK 0
#define NL_SIGN_KIT_ERR_NOT_INITIALIZED 1001
#define NL_SIGN_KIT_ERR_INVALID_ARGUMENT 1002
#define NL_SIGN_KIT_ERR_BUFFER_TOO_SMALL 1003
#define NL_SIGN_KIT_ERR_INTERNAL 1004

/* 版本号（静态字符串，调用方不要 free）。 */
const char *nl_sign_kit_version(void);

/*
 * 初始化：保存 app_key / app_secret 的内部副本。
 * 未初始化就调用签名类接口 → NL_SIGN_KIT_ERR_NOT_INITIALIZED。
 */
int32_t nl_sign_kit_init(const char *app_key, const char *app_secret);

/*
 * 教学演示专用：用编译进库的 demo 密钥初始化。
 *
 * 真实项目不要把密钥写进源码；密钥应由原生安全存储（Keychain/Keystore）
 * 或服务端下发后注入。这个函数只是为了让 L10 演示页的 Dart 时代码里
 * 完全不出现 secret，同时保持例子自包含。
 */
int32_t nl_sign_kit_init_demo(void);

/*
 * 对 message 做 HMAC-SHA256，输出 64 位小写十六进制 + '\0'。
 * out_size 至少 65。message 为空 → INVALID_ARGUMENT（业务规则：空 canonical 不可签）。
 */
int32_t nl_sign_kit_hmac_sha256_hex(const char *message,
                                    char *out,
                                    int32_t out_size);

/*
 * 设备指纹：FNV-1a 64（app_key + seed）→ 16 位小写十六进制 + '\0'。
 * out_size 至少 17。指纹用于设备识别，不是密码学用途。
 */
int32_t nl_sign_kit_fingerprint_hex(const char *seed,
                                    char *out,
                                    int32_t out_size);

/*
 * 二进制 CRC32（IEEE 802.3），用于本地缓存/大文件完整性校验。
 * length 由 Dart 侧传 int32_t；超 2GB 的文件请分块（教学点：FFI 里长度类型要显式）。
 */
int32_t nl_sign_kit_crc32(const uint8_t *data,
                          int32_t length,
                          uint32_t *out);

/*
 * 最近一次错误的可读描述（线程局部缓冲区，调用方不要 free）。
 * 每次成功/失败都会覆盖；返回的指针在下次调用前有效。
 */
const char *nl_sign_kit_last_error(void);

/*
 * 仅给 iOS 静态链接用：让 Swift 插件在 register 时“碰”一下 C 符号，
 * 防止链接器把整个 nl_sign_kit.c 目标文件当死代码裁掉。
 * 业务代码永远不需要调用它。
 */
int32_t nl_sign_kit_warmup(void);

#ifdef __cplusplus
} /* extern "C" */
#endif

#endif /* NL_SIGN_KIT_H */
