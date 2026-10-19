import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/error/error_messages.dart';
import '../../features/cart/api.dart';
import '../../features/cart/models.dart';
import '../../features/orders/api.dart';
import '../../features/orders/models.dart';
import '../../l10n/app_localizations.dart';

final checkoutControllerProvider =
    NotifierProvider<CheckoutController, CheckoutState>(CheckoutController.new);

/// 结算流程自身的失败原因（不是网络/存储错误）。
enum CheckoutFailure { emptyCart, nothingToRetry }

/// M12 进阶：结算协调器的业务异常。
///
/// 原来抛的是 `StateError('购物车为空')`——页面拿到后只能显示通用的"出了点问题"，
/// 用户不知道该怎么办、重试也永远失败。改成带原因的类型，并通过 [LocalizedException]
/// 自带当前语言的文案（协调器属于应用层，可以依赖 AppLocalizations；数据/领域层不行）。
class CheckoutException implements LocalizedException {
  const CheckoutException(this.reason);
  final CheckoutFailure reason;

  @override
  String localizedMessage(AppLocalizations l10n) => switch (reason) {
    CheckoutFailure.emptyCart => l10n.checkoutEmpty,
    CheckoutFailure.nothingToRetry => l10n.checkoutNothingToRetry,
  };

  @override
  String toString() => 'CheckoutException($reason)';
}

class CheckoutResult {
  const CheckoutResult({
    required this.order,
    required this.needsCartRetry,
    required this.needsAddressRetry,
  });
  final Order order;
  final bool needsCartRetry;
  final bool needsAddressRetry;
}

class CheckoutState {
  const CheckoutState({this.isSubmitting = false, this.result, this.error});
  final bool isSubmitting;
  final CheckoutResult? result;
  final Object? error;
  bool get needsRetry =>
      result != null && (result!.needsCartRetry || result!.needsAddressRetry);
}

/// 当前应用会话中的结算检查点，不是跨存储事务或重启恢复日志。
class _CheckoutAttempt {
  _CheckoutAttempt(this.cart, this.address);
  final CartSnapshot cart;
  final ShippingAddress address;
  Order? order;
  bool cartConsumed = false;
  bool addressSaved = false;
}

/// M10 维护演进：≈ iOS Coordinator，串联公开业务能力，页面只负责表单与导航。
/// 创建订单成功后只重试未完成步骤，不能把已落库订单当作“下单失败”。
class CheckoutController extends Notifier<CheckoutState> {
  Future<CheckoutResult>? _inFlight;
  _CheckoutAttempt? _attempt;

  @override
  CheckoutState build() => const CheckoutState();

  Future<CheckoutResult> submit(ShippingAddress address) {
    if (_inFlight != null) return _inFlight!;
    // 购物车尚未处理完成时优先恢复旧订单，不再创建新单。
    if (_attempt?.order != null && !_attempt!.cartConsumed) {
      return retryPending();
    }
    return _start(() async {
      final cart = await ref.read(cartProvider.notifier).capture();
      if (cart.items.isEmpty) {
        throw const CheckoutException(CheckoutFailure.emptyCart);
      }
      final attempt = _CheckoutAttempt(cart, address);
      return _complete(attempt);
    });
  }

  Future<CheckoutResult> retryPending() {
    if (_inFlight != null) return _inFlight!;
    final attempt = _attempt;
    if (attempt == null || attempt.order == null) {
      return Future.error(
        const CheckoutException(CheckoutFailure.nothingToRetry),
      );
    }
    return _start(() => _complete(attempt));
  }

  Future<CheckoutResult> _start(Future<CheckoutResult> Function() action) {
    state = CheckoutState(isSubmitting: true, result: state.result);
    // Future.microtask 让 _inFlight 在业务执行前就设置，重复提交共享同一任务。
    final task = Future.microtask(() async {
      try {
        final result = await action();
        if (ref.mounted) state = CheckoutState(result: result);
        return result;
      } catch (error) {
        if (ref.mounted) {
          state = CheckoutState(result: state.result, error: error);
        }
        rethrow;
      } finally {
        _inFlight = null;
      }
    });
    _inFlight = task;
    return task;
  }

  Future<CheckoutResult> _complete(_CheckoutAttempt attempt) async {
    attempt.order ??= await ref
        .read(ordersProvider.notifier)
        .placeOrder(cartItems: attempt.cart.items, address: attempt.address);
    // 新订单保存成功才替换有效检查点；失败仍能恢复上一单的附属步骤。
    _attempt = attempt;
    if (!attempt.cartConsumed) {
      try {
        await ref.read(cartProvider.notifier).consume(attempt.cart);
        attempt.cartConsumed = true;
      } catch (_) {
        /* 保留检查点，页面提示“订单已创建，购物车待同步”。 */
      }
    }
    if (!attempt.addressSaved) {
      try {
        await ref.read(addressStorageProvider).save(attempt.address);
        attempt.addressSaved = true;
        if (ref.mounted) ref.invalidate(savedAddressProvider);
      } catch (_) {
        /* 默认地址是附属偏好，不回滚已经成功的订单。 */
      }
    }
    return CheckoutResult(
      order: attempt.order!,
      needsCartRetry: !attempt.cartConsumed,
      needsAddressRetry: !attempt.addressSaved,
    );
  }
}
