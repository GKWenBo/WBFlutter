import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../cart/domain/cart_item.dart';
import '../../cart/presentation/providers/cart_providers.dart';
import '../domain/order.dart';
import 'providers/orders_providers.dart';

/// 结算页（/checkout，已进 _protectedPaths：未登录点"去结算"会被 M8 的 redirect
/// 拦去登录页，登录成功再回来——当初留的扩展点在这里兑现了）。
///
/// 结构：商品清单（只读）+ 收货地址表单（复用 M8 的 Form 套路）+ 底部提交栏。
/// 用 ConsumerStatefulWidget：要持有 FormKey/TextEditingController（需要 dispose），
/// 还要一个 _submitting 标志做"防重复提交"。
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
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    // 预填上次保存的地址。异步取值回来再塞进 controller——
    // 注意用一次性的 read(...future)，别在 build 里 watch 完往 controller.text 赋值：
    // 那样每次重建都会把用户正在编辑的内容覆盖掉。
    ref.read(savedAddressProvider.future).then((address) {
      if (!mounted || address == null) return; // 异步回调先查 mounted（≈ weak self）
      _nameController.text = address.name;
      _phoneController.text = address.phone;
      _detailController.text = address.detail;
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
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final cartItems = ref.read(cartProvider).asData?.value ?? const [];
    if (cartItems.isEmpty) return; // 兜底：正常流程进不来空车结算

    final address = ShippingAddress(
      name: _nameController.text.trim(),
      phone: _phoneController.text.trim(),
      detail: _detailController.text.trim(),
    );

    setState(() => _submitting = true);
    try {
      // ↓ 这里就是"UI 层编排多个 feature"：下单 → 存默认地址 → 清空购物车 → 跳转。
      // 每一步各自的 provider 只管自己的事，串联顺序由页面决定。
      await ref
          .read(ordersProvider.notifier)
          .placeOrder(cartItems: cartItems, address: address);
      await ref.read(addressStorageProvider).save(address);
      ref.invalidate(savedAddressProvider); // 让"默认地址"下次重读到新值
      await ref.read(cartProvider.notifier).clear();

      if (!mounted) return; // await 之后要用 context，先确认页面还活着
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('下单成功！')),
      );
      // pushReplacement：用订单列表**顶替**当前的结算页——
      // 从订单列表返回时回到购物车，而不是回到一个已经没意义的结算页。
      context.pushReplacement('/orders');
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('下单失败：$e')),
      );
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // watch 购物车：结算页展示的清单/合计要和购物车实时一致。
    final cartItems = ref.watch(cartProvider).asData?.value ?? const [];
    final totalPrice = ref.watch(cartTotalPriceProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('确认订单')),
      body: cartItems.isEmpty
          ? const Center(child: Text('购物车是空的，没什么可结算的'))
          : Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Text('收货信息', style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _nameController,
                    decoration: const InputDecoration(
                      labelText: '收货人',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.person_outline),
                    ),
                    textInputAction: TextInputAction.next, // 键盘回车 = 跳下一格
                    validator: (v) =>
                        (v == null || v.trim().isEmpty) ? '请填写收货人' : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _phoneController,
                    decoration: const InputDecoration(
                      labelText: '手机号',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.phone_iphone),
                    ),
                    keyboardType: TextInputType.phone,
                    textInputAction: TextInputAction.next,
                    validator: (v) {
                      final phone = v?.trim() ?? '';
                      if (phone.isEmpty) return '请填写手机号';
                      // 教学从简：11 位数字。真实项目用正则或专门的校验库。
                      if (phone.length != 11 ||
                          int.tryParse(phone) == null) {
                        return '手机号应为 11 位数字';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _detailController,
                    decoration: const InputDecoration(
                      labelText: '详细地址',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.location_on_outlined),
                    ),
                    maxLines: 2,
                    validator: (v) =>
                        (v == null || v.trim().isEmpty) ? '请填写详细地址' : null,
                  ),
                  const SizedBox(height: 24),
                  Text('商品清单', style: Theme.of(context).textTheme.titleMedium),
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
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        '合计：\$${totalPrice.toStringAsFixed(2)}',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          color: Theme.of(context).colorScheme.primary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    FilledButton(
                      // onPressed: null 就是 Material 的"禁用态"（自动变灰、不可点）——
                      // 提交中把它置空，配合转圈图标，双保险防重复提交。
                      onPressed: _submitting ? null : _submit,
                      child: _submitting
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('提交订单'),
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
            '\$${item.unitPrice.toStringAsFixed(2)} × ${item.quantity}',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}
