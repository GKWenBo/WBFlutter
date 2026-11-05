#include "nl_sign_kit.h"

#include <stddef.h>
#include <string.h>

/* ────────────────────────── SHA-256（教学版，自包含） ───────────────────── */

typedef struct {
  uint32_t state[8];
  uint64_t bit_len;
  uint8_t buffer[64];
  size_t buffer_len;
} nl_sha256_ctx;

static const uint32_t NL_SHA256_K[64] = {
    0x428a2f98u, 0x71374491u, 0xb5c0fbcfu, 0xe9b5dba5u, 0x3956c25bu,
    0x59f111f1u, 0x923f82a4u, 0xab1c5ed5u, 0xd807aa98u, 0x12835b01u,
    0x243185beu, 0x550c7dc3u, 0x72be5d74u, 0x80deb1feu, 0x9bdc06a7u,
    0xc19bf174u, 0xe49b69c1u, 0xefbe4786u, 0x0fc19dc6u, 0x240ca1ccu,
    0x2de92c6fu, 0x4a7484aau, 0x5cb0a9dcu, 0x76f988dau, 0x983e5152u,
    0xa831c66du, 0xb00327c8u, 0xbf597fc7u, 0xc6e00bf3u, 0xd5a79147u,
    0x06ca6351u, 0x14292967u, 0x27b70a85u, 0x2e1b2138u, 0x4d2c6dfcu,
    0x53380d13u, 0x650a7354u, 0x766a0abbu, 0x81c2c92eu, 0x92722c85u,
    0xa2bfe8a1u, 0xa81a664bu, 0xc24b8b70u, 0xc76c51a3u, 0xd192e819u,
    0xd6990624u, 0xf40e3585u, 0x106aa070u, 0x19a4c116u, 0x1e376c08u,
    0x2748774cu, 0x34b0bcb5u, 0x391c0cb3u, 0x4ed8aa4au, 0x5b9cca4fu,
    0x682e6ff3u, 0x748f82eeu, 0x78a5636fu, 0x84c87814u, 0x8cc70208u,
    0x90befffau, 0xa4506cebu, 0xbef9a3f7u, 0xc67178f2u};

static uint32_t nl_rotr(uint32_t x, uint32_t n) {
  return (x >> n) | (x << (32u - n));
}

static void nl_sha256_compress(nl_sha256_ctx *ctx, const uint8_t block[64]) {
  uint32_t w[64];
  for (int i = 0; i < 16; i++) {
    w[i] = ((uint32_t)block[i * 4] << 24) |
           ((uint32_t)block[i * 4 + 1] << 16) |
           ((uint32_t)block[i * 4 + 2] << 8) |
           ((uint32_t)block[i * 4 + 3]);
  }
  for (int i = 16; i < 64; i++) {
    uint32_t s0 = nl_rotr(w[i - 15], 7) ^ nl_rotr(w[i - 15], 18) ^ (w[i - 15] >> 3);
    uint32_t s1 = nl_rotr(w[i - 2], 17) ^ nl_rotr(w[i - 2], 19) ^ (w[i - 2] >> 10);
    w[i] = w[i - 16] + s0 + w[i - 7] + s1;
  }

  uint32_t a = ctx->state[0];
  uint32_t b = ctx->state[1];
  uint32_t c = ctx->state[2];
  uint32_t d = ctx->state[3];
  uint32_t e = ctx->state[4];
  uint32_t f = ctx->state[5];
  uint32_t g = ctx->state[6];
  uint32_t h = ctx->state[7];

  for (int i = 0; i < 64; i++) {
    uint32_t s1 = nl_rotr(e, 6) ^ nl_rotr(e, 11) ^ nl_rotr(e, 25);
    uint32_t ch = (e & f) ^ ((~e) & g);
    uint32_t temp1 = h + s1 + ch + NL_SHA256_K[i] + w[i];
    uint32_t s0 = nl_rotr(a, 2) ^ nl_rotr(a, 13) ^ nl_rotr(a, 22);
    uint32_t maj = (a & b) ^ (a & c) ^ (b & c);
    uint32_t temp2 = s0 + maj;

    h = g;
    g = f;
    f = e;
    e = d + temp1;
    d = c;
    c = b;
    b = a;
    a = temp1 + temp2;
  }

  ctx->state[0] += a;
  ctx->state[1] += b;
  ctx->state[2] += c;
  ctx->state[3] += d;
  ctx->state[4] += e;
  ctx->state[5] += f;
  ctx->state[6] += g;
  ctx->state[7] += h;
}

static void nl_sha256_init(nl_sha256_ctx *ctx) {
  ctx->state[0] = 0x6a09e667u;
  ctx->state[1] = 0xbb67ae85u;
  ctx->state[2] = 0x3c6ef372u;
  ctx->state[3] = 0xa54ff53au;
  ctx->state[4] = 0x510e527fu;
  ctx->state[5] = 0x9b05688cu;
  ctx->state[6] = 0x1f83d9abu;
  ctx->state[7] = 0x5be0cd19u;
  ctx->bit_len = 0;
  ctx->buffer_len = 0;
}

static void nl_sha256_update(nl_sha256_ctx *ctx, const uint8_t *data, size_t len) {
  if (len == 0) {
    return;
  }
  ctx->bit_len += (uint64_t)len * 8u;
  size_t offset = 0;
  if (ctx->buffer_len > 0) {
    size_t need = 64 - ctx->buffer_len;
    size_t take = len < need ? len : need;
    memcpy(ctx->buffer + ctx->buffer_len, data, take);
    ctx->buffer_len += take;
    offset += take;
    if (ctx->buffer_len == 64) {
      nl_sha256_compress(ctx, ctx->buffer);
      ctx->buffer_len = 0;
    }
  }
  while (offset + 64 <= len) {
    nl_sha256_compress(ctx, data + offset);
    offset += 64;
  }
  if (offset < len) {
    size_t remain = len - offset;
    memcpy(ctx->buffer, data + offset, remain);
    ctx->buffer_len = remain;
  }
}

static void nl_sha256_final(nl_sha256_ctx *ctx, uint8_t out[32]) {
  uint64_t bit_len = ctx->bit_len;
  ctx->buffer[ctx->buffer_len++] = 0x80u;
  if (ctx->buffer_len > 56) {
    while (ctx->buffer_len < 64) {
      ctx->buffer[ctx->buffer_len++] = 0x00u;
    }
    nl_sha256_compress(ctx, ctx->buffer);
    ctx->buffer_len = 0;
  }
  while (ctx->buffer_len < 56) {
    ctx->buffer[ctx->buffer_len++] = 0x00u;
  }
  for (int i = 7; i >= 0; i--) {
    ctx->buffer[56 + (7 - i)] = (uint8_t)((bit_len >> (i * 8)) & 0xffu);
  }
  nl_sha256_compress(ctx, ctx->buffer);

  for (int i = 0; i < 8; i++) {
    out[i * 4] = (uint8_t)((ctx->state[i] >> 24) & 0xffu);
    out[i * 4 + 1] = (uint8_t)((ctx->state[i] >> 16) & 0xffu);
    out[i * 4 + 2] = (uint8_t)((ctx->state[i] >> 8) & 0xffu);
    out[i * 4 + 3] = (uint8_t)(ctx->state[i] & 0xffu);
  }
}

static void nl_sha256(const uint8_t *data, size_t len, uint8_t out[32]) {
  nl_sha256_ctx ctx;
  nl_sha256_init(&ctx);
  nl_sha256_update(&ctx, data, len);
  nl_sha256_final(&ctx, out);
}

/* ────────────────────────── HMAC-SHA256 ─────────────────────────────────── */

static void nl_hmac_sha256(const uint8_t *key,
                           size_t key_len,
                           const uint8_t *data,
                           size_t data_len,
                           uint8_t out[32]) {
  uint8_t normalized_key[64];
  uint8_t inner_pad[64];
  uint8_t outer_pad[64];
  uint8_t inner_digest[32];
  nl_sha256_ctx ctx;

  memset(normalized_key, 0, sizeof(normalized_key));
  if (key_len > sizeof(normalized_key)) {
    nl_sha256(key, key_len, normalized_key);
  } else if (key_len > 0) {
    memcpy(normalized_key, key, key_len);
  }

  for (size_t i = 0; i < sizeof(normalized_key); i++) {
    inner_pad[i] = (uint8_t)(normalized_key[i] ^ 0x36u);
    outer_pad[i] = (uint8_t)(normalized_key[i] ^ 0x5cu);
  }

  nl_sha256_init(&ctx);
  nl_sha256_update(&ctx, inner_pad, sizeof(inner_pad));
  nl_sha256_update(&ctx, data, data_len);
  nl_sha256_final(&ctx, inner_digest);

  nl_sha256_init(&ctx);
  nl_sha256_update(&ctx, outer_pad, sizeof(outer_pad));
  nl_sha256_update(&ctx, inner_digest, sizeof(inner_digest));
  nl_sha256_final(&ctx, out);

  memset(normalized_key, 0, sizeof(normalized_key));
  memset(inner_pad, 0, sizeof(inner_pad));
  memset(outer_pad, 0, sizeof(outer_pad));
  memset(inner_digest, 0, sizeof(inner_digest));
}

/* ────────────────────────── SDK 状态与工具 ─────────────────────────────── */

#define NL_MAX_KEY_LEN 128

static char g_app_key[NL_MAX_KEY_LEN];
static char g_app_secret[NL_MAX_KEY_LEN];
static int g_initialized = 0;
static volatile int32_t g_warmup_count = 0;

/* 线程局部：多个 isolate 各自在独立线程上调用 FFI 时，错误消息不会串台。 */
static _Thread_local char g_last_error[256];

static void nl_set_error(const char *message) {
  if (message == NULL) {
    g_last_error[0] = '\0';
    return;
  }
  size_t len = strlen(message);
  if (len >= sizeof(g_last_error)) {
    len = sizeof(g_last_error) - 1;
  }
  memcpy(g_last_error, message, len);
  g_last_error[len] = '\0';
}

static void nl_to_hex(const uint8_t *input, size_t len, char *out) {
  static const char hex_digits[] = "0123456789abcdef";
  for (size_t i = 0; i < len; i++) {
    out[i * 2] = hex_digits[input[i] >> 4];
    out[i * 2 + 1] = hex_digits[input[i] & 0x0fu];
  }
  out[len * 2] = '\0';
}

static void nl_uint64_to_hex(uint64_t value, char *out) {
  static const char hex_digits[] = "0123456789abcdef";
  for (int i = 0; i < 16; i++) {
    uint8_t nibble = (uint8_t)((value >> ((15 - i) * 4)) & 0x0fu);
    out[i] = hex_digits[nibble];
  }
  out[16] = '\0';
}

static uint64_t nl_fnv1a64(const char *text, uint64_t hash) {
  const uint8_t *p = (const uint8_t *)text;
  while (*p != '\0') {
    hash ^= (uint64_t)(*p);
    hash *= 1099511628211ULL;
    p++;
  }
  return hash;
}

/* ────────────────────────── 对外 API ───────────────────────────────────── */

const char *nl_sign_kit_version(void) {
  return "1.0.0";
}

int32_t nl_sign_kit_warmup(void) {
  g_warmup_count++;
  return g_warmup_count;
}

int32_t nl_sign_kit_init(const char *app_key, const char *app_secret) {
  if (app_key == NULL || app_secret == NULL) {
    nl_set_error("app_key / app_secret 不能为 NULL");
    return NL_SIGN_KIT_ERR_INVALID_ARGUMENT;
  }
  size_t key_len = strlen(app_key);
  size_t secret_len = strlen(app_secret);
  if (key_len == 0 || secret_len == 0) {
    nl_set_error("app_key / app_secret 不能为空");
    return NL_SIGN_KIT_ERR_INVALID_ARGUMENT;
  }
  if (key_len >= sizeof(g_app_key) || secret_len >= sizeof(g_app_secret)) {
    nl_set_error("app_key / app_secret 过长（各上限 127 字节）");
    return NL_SIGN_KIT_ERR_INVALID_ARGUMENT;
  }

  memset(g_app_key, 0, sizeof(g_app_key));
  memset(g_app_secret, 0, sizeof(g_app_secret));
  memcpy(g_app_key, app_key, key_len);
  memcpy(g_app_secret, app_secret, secret_len);
  g_initialized = 1;
  nl_set_error("");
  return NL_SIGN_KIT_OK;
}

int32_t nl_sign_kit_init_demo(void) {
  // 演示密钥只在 C 侧出现；Dart 页面通过 FFI 调这个函数，不接触 secret。
  return nl_sign_kit_init("native_lab_demo", "demo-secret-2026");
}

int32_t nl_sign_kit_hmac_sha256_hex(const char *message,
                                    char *out,
                                    int32_t out_size) {
  if (out == NULL || out_size < 65) {
    nl_set_error("输出缓冲区不足：HMAC 十六进制需要至少 65 字节");
    return NL_SIGN_KIT_ERR_BUFFER_TOO_SMALL;
  }
  if (!g_initialized) {
    nl_set_error("SDK 尚未初始化，请先调用 nl_sign_kit_init");
    return NL_SIGN_KIT_ERR_NOT_INITIALIZED;
  }
  if (message == NULL || message[0] == '\0') {
    nl_set_error("message 不能为空：空 canonical 不可签名");
    return NL_SIGN_KIT_ERR_INVALID_ARGUMENT;
  }

  uint8_t digest[32];
  nl_hmac_sha256((const uint8_t *)g_app_secret, strlen(g_app_secret),
                 (const uint8_t *)message, strlen(message), digest);
  nl_to_hex(digest, sizeof(digest), out);
  memset(digest, 0, sizeof(digest));
  nl_set_error("");
  return NL_SIGN_KIT_OK;
}

int32_t nl_sign_kit_fingerprint_hex(const char *seed,
                                    char *out,
                                    int32_t out_size) {
  if (out == NULL || out_size < 17) {
    nl_set_error("输出缓冲区不足：指纹需要至少 17 字节");
    return NL_SIGN_KIT_ERR_BUFFER_TOO_SMALL;
  }
  if (!g_initialized) {
    nl_set_error("SDK 尚未初始化，请先调用 nl_sign_kit_init");
    return NL_SIGN_KIT_ERR_NOT_INITIALIZED;
  }
  if (seed == NULL || seed[0] == '\0') {
    nl_set_error("seed 不能为空");
    return NL_SIGN_KIT_ERR_INVALID_ARGUMENT;
  }

  uint64_t hash = 1469598103934665603ULL; /* FNV-1a 64 offset basis */
  hash = nl_fnv1a64(g_app_key, hash);
  hash = nl_fnv1a64(seed, hash);
  nl_uint64_to_hex(hash, out);
  nl_set_error("");
  return NL_SIGN_KIT_OK;
}

int32_t nl_sign_kit_crc32(const uint8_t *data,
                          int32_t length,
                          uint32_t *out) {
  if (out == NULL) {
    nl_set_error("out 不能为 NULL");
    return NL_SIGN_KIT_ERR_INVALID_ARGUMENT;
  }
  if (length < 0) {
    nl_set_error("length 不能为负数");
    return NL_SIGN_KIT_ERR_INVALID_ARGUMENT;
  }
  if (data == NULL && length > 0) {
    nl_set_error("data 为 NULL 但 length > 0");
    return NL_SIGN_KIT_ERR_INVALID_ARGUMENT;
  }

  uint32_t crc = 0xFFFFFFFFu;
  for (int32_t i = 0; i < length; i++) {
    crc ^= (uint32_t)data[i];
    for (int bit = 0; bit < 8; bit++) {
      if ((crc & 1u) != 0u) {
        crc = (crc >> 1) ^ 0xEDB88320u;
      } else {
        crc >>= 1;
      }
    }
  }
  *out = crc ^ 0xFFFFFFFFu;
  nl_set_error("");
  return NL_SIGN_KIT_OK;
}

const char *nl_sign_kit_last_error(void) {
  return g_last_error;
}
