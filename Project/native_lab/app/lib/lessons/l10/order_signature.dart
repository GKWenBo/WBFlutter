/// L10 的纯 Dart 业务逻辑：签名前的 canonical payload + 一个 CRC32 参考实现。
///
/// 真实项目里签名失败十有八九不是算法错，而是**两端 canonical 拼法不一致**：
/// 参数顺序、编码方式、时间戳单位、body 是否参与……这里把规则显式写出来并配单测，
/// 服务端必须按同一份规则拼。iOS 类比：这类“字符串拼接 + 排序”逻辑适合放在
/// 纯 Swift 工具类型里，别塞进 VC。
library;

/// 生成下单请求的 canonical payload。
///
/// 规则（本课自定义，真实项目以服务端文档为准）：
/// - query 按 key 升序；
/// - key/value 用 `Uri.encodeComponent` 编码（空格是 `%20`，不是 `+`）；
/// - 用 `\n` 拼接 method / path / query / timestampMs / body。
String buildOrderCanonicalPayload({
  required String method,
  required String path,
  required int timestampMs,
  required Map<String, String> query,
  required String body,
}) {
  final keys = query.keys.toList()..sort();
  final encodedQuery = keys
      .map(
        (key) =>
            '${Uri.encodeComponent(key)}=${Uri.encodeComponent(query[key]!)}',
      )
      .join('&');
  return '$method\n$path\n$encodedQuery\n$timestampMs\n$body';
}

/// 与 C 侧一致的 CRC32（IEEE 802.3）参考实现，用来和 FFI 结果对比。
///
/// 注意：Dart 的位运算在 Web 上是 32 位有符号，这里用 `& 0xFFFFFFFF` 收口；
/// 移动端/桌面 VM 上同样是确定结果。
int dartCrc32(List<int> bytes) {
  var crc = 0xFFFFFFFF;
  for (final byte in bytes) {
    crc ^= byte & 0xFF;
    for (var bit = 0; bit < 8; bit++) {
      if ((crc & 1) != 0) {
        crc = (crc >> 1) ^ 0xEDB88320;
      } else {
        crc >>= 1;
      }
    }
  }
  return (crc ^ 0xFFFFFFFF) & 0xFFFFFFFF;
}
