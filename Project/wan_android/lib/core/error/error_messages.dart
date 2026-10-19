import '../../l10n/app_localizations.dart';
import 'failure.dart';

/// 扩展点：**应用层/展示层**自己定义的业务异常，可以实现它来提供当前语言的文案，
/// describeError 会优先采用。（core 不认识各模块的异常类型，也不该认识。）
///
/// 注意分层：数据层/领域层的异常**不要**实现它——它们拿不到也不该依赖 AppLocalizations，
/// 应该像 AppException 那样只给类型，由这里按类型翻译。
/// 例：app/checkout/checkout_controller.dart 的 CheckoutException。
abstract interface class LocalizedException implements Exception {
  String localizedMessage(AppLocalizations l10n);
}

/// M12 国际化进阶：把"任意错误对象"翻译成当前语言的人话。
///
/// 分工（≈ iOS 的 Error + LocalizedError）：
/// - 数据层只抛**带类型的** AppException（NetworkException / ServerException …），不碰文案；
/// - 这里是统一的翻译入口；应用层的业务异常通过 [LocalizedException] 自带文案。
///
/// 写成 AppLocalizations 的扩展而不是独立函数，调用处读起来就是
/// `l10n.describeError(e)`——和 `l10n.retry` 这种普通文案取法一致。
extension AppErrorMessages on AppLocalizations {
  String describeError(Object error) => switch (error) {
    LocalizedException() => error.localizedMessage(this),
    AppException() => _describeAppException(error),
    // 非 AppException（StateError、存储失败等）是程序内部问题：
    // 它们的 message 是写给开发者的中文，不能原样甩给德语/阿语用户，统一给通用文案。
    _ => errorUnknown,
  };

  /// 单独一个 switch、**不写 `_` 默认分支**：AppException 是 sealed，
  /// 这样将来新增子类时这里会编译报错，逼你补文案。
  /// （如果把这些分支和上面的 `_ =>` 写在同一个 switch 里，新子类会被 `_` 悄悄吞成通用文案，
  /// 编译器不会提醒——穷尽检查只在没有兜底分支时才起作用。）
  String _describeAppException(AppException error) => switch (error) {
    NetworkException(issue: NetworkIssue.timeout) => errorNetworkTimeout,
    NetworkException(issue: NetworkIssue.unreachable) => errorNoConnection,
    ServerException(:final code) => errorServer(code?.toString() ?? '?'),
    InvalidCredentialsException() => errorInvalidCredentials,
    ParseException() => errorParse,
    UnknownException() => errorUnknown,
  };
}
