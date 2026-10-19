import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/checkout/checkout_controller.dart';
import '../../../core/error/error_messages.dart';
import '../../../core/text/normalize_digits.dart';
import '../../../l10n/app_localizations.dart';
import '../../cart/api.dart';
import '../../cart/models.dart';
import '../domain/order.dart';
import 'providers/orders_providers.dart';

/// 结算页（/checkout，已进 _protectedPaths：未登录点"去结算"会被 M8 的 redirect
/// 拦去登录页，登录成功后可再进入结算页——当初留的扩展点在这里兑现了）。
///
/// 结构：商品清单（只读）+ 收货地址表单（复用 M8 的 Form 套路）+ 底部提交栏。
/// 用 ConsumerStatefulWidget：要持有 FormKey/TextEditingController（需要 dispose），
/// 订阅应用协调器的 isSubmitting 禁用重复提交。
class CheckoutPage extends ConsumerStatefulWidget {
  const CheckoutPage({super.key});

  @override
  ConsumerState<CheckoutPage> createState() => _CheckoutPageState();
}

class _CheckoutPageState extends ConsumerState<CheckoutPage> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _detailController = TextEditingController();

  @override
  void initState() {
    super.initState();
    // 预填上次保存的地址。异步取值回来再塞进 controller——
    // 注意用一次性的 read(...future)，别在 build 里 watch 完往 controller.text 赋值：
    // 那样每次重建都会把用户正在编辑的内容覆盖掉。
    ref
        .read(savedAddressProvider.future)
        .then((address) {
          if (!mounted || address == null) {
            return; // 异步回调先查 mounted（≈ weak self）
          }
          if (_nameController.text.isEmpty) _nameController.text = address.name;
          if (_phoneController.text.isEmpty) {
            _phoneController.text = address.phone;
          }
          if (_detailController.text.isEmpty) {
            _detailController.text = address.detail;
          }
        })
        .catchError((Object _, StackTrace _) {
          /* 预填失败不阻止手工输入。 */
        });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _detailController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    // 表单校验不过就不往下走（validator 的红字会自动显示在各输入框下方）。
    final resuming =
        ref.read(checkoutControllerProvider).result?.needsCartRetry == true;
    if (!resuming && !(_formKey.currentState?.validate() ?? false)) return;

    final cartItems = ref.read(cartProvider).asData?.value ?? const [];
    if (!resuming && cartItems.isEmpty) return; // 兜底：正常流程进不来空车结算

    final address = ShippingAddress(
      name: _nameController.text.trim(),
      // M12：阿语键盘输入的是 ١٣٨…，存盘前统一成 ASCII 数字（校验里也做了同样的归一化）。
      phone: normalizeDigits(_phoneController.text.trim()),
      detail: _detailController.text.trim(),
    );

    final l10n = AppLocalizations.of(context);
    try {
      final controller = ref.read(checkoutControllerProvider.notifier);
      final result = await (resuming
          ? controller.retryPending()
          : controller.submit(address));
      if (!mounted) return;
      if (result.needsCartRetry) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.orderCreatedCartSyncFailed)),
        );
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            result.needsAddressRetry
                ? l10n.orderPlacedAddressNotSaved
                : l10n.orderPlaced,
          ),
        ),
      );
      context.pushReplacement('/orders');
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.orderFailed(l10n.describeError(error)))),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final checkout = ref.watch(checkoutControllerProvider);
    final submitting = checkout.isSubmitting;
    // watch 购物车：结算页展示的清单/合计要和购物车实时一致。
    final cartItems = ref.watch(cartProvider).asData?.value ?? const [];
    final totalPrice = ref.watch(cartTotalPriceProvider);
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.checkoutTitle)),
      body: cartItems.isEmpty
          ? Center(child: Text(l10n.checkoutEmpty))
          : Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Text(
                    l10n.shippingInfo,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _nameController,
                    decoration: InputDecoration(
                      labelText: l10n.recipientLabel,
                      border: const OutlineInputBorder(),
                      prefixIcon: const Icon(Icons.person_outline),
                    ),
                    textInputAction: TextInputAction.next, // 键盘回车 = 跳下一格
                    validator: (v) => (v == null || v.trim().isEmpty)
                        ? l10n.recipientRequired
                        : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _phoneController,
                    decoration: InputDecoration(
                      labelText: l10n.phoneLabel,
                      border: const OutlineInputBorder(),
                      prefixIcon: const Icon(Icons.phone_iphone),
                    ),
                    keyboardType: TextInputType.phone,
                    textInputAction: TextInputAction.next,
                    // M12：电话号码/邮箱/验证码这类"天生从左往右读"的内容，在阿语界面里也固定 LTR，
                    // 否则光标和对齐会跑到右边，号码分段读起来是反的。
                    // ≈ iOS 给 UITextField 设 semanticContentAttribute = .forceLeftToRight。
                    textDirection: TextDirection.ltr,
                    validator: (v) {
                      // 先归一化：阿语键盘输入的 ١٣٨٠٠١٣٨٠٠٠ 也算 11 位数字。
                      final phone = normalizeDigits(v?.trim() ?? '');
                      if (phone.isEmpty) return l10n.phoneRequired;
                      // 教学从简：11 位数字。真实项目用正则或专门的校验库。
                      // （这条规则本身也带地域性：只对中国大陆手机号成立，国际化时要换成按国家校验。）
                      if (phone.length != 11 || int.tryParse(phone) == null) {
                        return l10n.phoneInvalid;
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _detailController,
                    decoration: InputDecoration(
                      labelText: l10n.addressLabel,
                      border: const OutlineInputBorder(),
                      prefixIcon: const Icon(Icons.location_on_outlined),
                    ),
                    maxLines: 2,
                    validator: (v) => (v == null || v.trim().isEmpty)
                        ? l10n.addressRequired
                        : null,
                  ),
                  const SizedBox(height: 24),
                  Text(
                    l10n.orderItems,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  // 只读的商品清单：不用 ListView.builder 嵌套（外层已是 ListView），
                  // 结算清单条数有限，直接 map 成一组行即可。
                  for (final item in cartItems) _CheckoutRow(item: item),
                ],
              ),
            ),
      bottomNavigationBar: cartItems.isEmpty
          ? null
          : SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                // M12 国际化进阶：原来是 Row[Expanded(合计), FilledButton]，按钮宽度完全由文案决定。
                // 德语的下单按钮按法律要求必须写 "Zahlungspflichtig bestellen"（见讲义），
                // 窄屏上合计 + 按钮放不进一行 → overflow。
                // 改用 OverflowBar："放得下就横排，放不下就竖排"——
                // 中文/英文照旧是一行（合计在行首、按钮在行尾，视觉和原来一样）；
                // 德语窄屏自动变成两行（合计在上、按钮在下，都靠行尾）。
                // 它本来就是为对话框按钮的多语言场景设计的，≈ iOS 里 UIStackView 在
                // 大字号/长文案时把 axis 从 horizontal 切到 vertical 的那种自适应。
                // （别用 Flexible 平分宽度：中文的合计也只剩一半，在 375pt 屏上就会被折行。）
                child: OverflowBar(
                  alignment: MainAxisAlignment.spaceBetween,
                  spacing: 12,
                  overflowAlignment: OverflowBarAlignment.end,
                  overflowSpacing: 8,
                  children: [
                    Text(
                      l10n.totalAmount(totalPrice),
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: Theme.of(context).colorScheme.primary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    FilledButton(
                      // onPressed: null 就是 Material 的"禁用态"（自动变灰、不可点）——
                      // 提交中把它置空，配合转圈图标，双保险防重复提交。
                      onPressed: submitting ? null : _submit,
                      child: submitting
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Text(
                              checkout.result?.needsCartRetry == true
                                  ? l10n.retryCheckout
                                  : l10n.submitOrder,
                            ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}

/// 结算清单的一行（只读版购物车行：没有步进器、不能滑动删除）。
class _CheckoutRow extends StatelessWidget {
  final CartItem item;
  const _CheckoutRow({required this.item});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: CachedNetworkImage(
              imageUrl: item.thumbnail,
              width: 56,
              height: 56,
              fit: BoxFit.cover,
              errorWidget: (c, u, e) => const ColoredBox(
                color: Color(0x11000000),
                child: Icon(Icons.image_outlined),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              item.title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 14),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            AppLocalizations.of(
              context,
            ).unitPriceTimesQuantity(item.unitPrice, item.quantity),
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}
