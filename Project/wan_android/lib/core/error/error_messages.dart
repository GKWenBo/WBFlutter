import '../../l10n/app_localizations.dart';
import 'failure.dart';

/// M12 国际化进阶：把"任意错误对象"翻译成当前语言的人话。
///
/// 分工（≈ iOS 的 Error + LocalizedError）：
/// - 数据层只抛**带类型的** AppException（NetworkException / ServerException …），不碰文案；
/// - 这里是唯一的翻译点：按类型穷尽 switch，sealed 保证将来加了新异常子类会编译报错提醒你补文案。
///
/// 写成 AppLocalizations 的扩展而不是独立函数，调用处读起来就是
/// `l10n.describeError(e)`——和 `l10n.retry` 这种普通文案取法一致。
extension AppErrorMessages on AppLocalizations {
  String describeError(Object error) {
    return switch (error) {
      NetworkException(issue: NetworkIssue.timeout) => errorNetworkTimeout,
      NetworkException(issue: NetworkIssue.unreachable) => errorNoConnection,
      ServerException(:final code) => errorServer(code?.toString() ?? '?'),
      ParseException() => errorParse,
      UnknownException() => errorUnknown,
      // 非 AppException（StateError、存储失败等）是程序内部问题：
      // 它们的 message 是写给开发者的中文，不能原样甩给德语/阿语用户，统一给通用文案。
      _ => errorUnknown,
    };
  }
}
