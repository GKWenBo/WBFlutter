import '../../../l10n/app_localizations.dart';
import '../domain/order.dart';

/// M12：订单状态 → 当前语言的文案。
///
/// 为什么用 switch 而不是 `Map<OrderStatus, String>`：switch 表达式对枚举是**穷尽检查**的，
/// 以后加一个 OrderStatus.refunded，这里不补分支直接编译报错；Map 漏了只会运行时拿到 null。
/// ≈ Swift 里对 enum 的 switch 不写 default，让编译器替你盯着。
extension OrderStatusText on OrderStatus {
  String localizedLabel(AppLocalizations l10n) => switch (this) {
    OrderStatus.submitted => l10n.orderStatusSubmitted,
    OrderStatus.paid => l10n.orderStatusPaid,
    OrderStatus.shipped => l10n.orderStatusShipped,
  };
}
