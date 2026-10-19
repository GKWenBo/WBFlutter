/// 统一的应用层异常 ≈ 你 iOS 里把 URLSession/解码 各种底层错误归一成的一个 enum。
///
/// 用 sealed class（呼应 M2 学的）：子类就这几种，UI/repository 可以用穷尽 switch 处理，
/// 编译器保证你不会漏掉某种错误态。
///
/// M12 国际化进阶：[message] 降级为**给开发者看的诊断信息**（日志、断点里看），
/// 不再直接显示给用户。原因：数据层拿不到 BuildContext，也不该知道用户选了哪种语言；
/// 它只负责说清"是哪一类错"（类型 + 少量结构化字段，如 [NetworkIssue]、状态码），
/// 由 UI 层按类型翻译成当前语言的文案（见 core/error/error_messages.dart）。
/// ≈ iOS 里 Error 只带 code/domain，LocalizedError.errorDescription 在展示层取本地化串。
sealed class AppException implements Exception {
  final String message; // 开发者诊断信息（不面向用户，不做翻译）
  const AppException(this.message);

  @override
  String toString() => message;
}

/// 网络错误的具体种类：UI 需要据此给出不同的提示（"稍后重试" vs "检查网络"）。
/// 用结构化字段而不是靠解析 message 字符串判断——字符串一翻译就对不上了。
enum NetworkIssue { timeout, unreachable }

/// 网络层错误：超时、断网、连不上。
class NetworkException extends AppException {
  final NetworkIssue issue;
  const NetworkException(
    super.message, {
    this.issue = NetworkIssue.unreachable,
  });
}

/// 服务器返回非 2xx（4xx/5xx）。
class ServerException extends AppException {
  final int? code;
  const ServerException(super.message, {this.code});
}

/// 解析/数据格式错误。
class ParseException extends AppException {
  const ParseException(super.message);
}

/// 兜底未知错误。
class UnknownException extends AppException {
  const UnknownException(super.message);
}
