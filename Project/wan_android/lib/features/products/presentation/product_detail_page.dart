import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/error/error_messages.dart';
import '../../../core/widgets/run_ui_action.dart';
import '../../../l10n/app_localizations.dart';
import '../../cart/api.dart';
import '../../favorites/api.dart';
import '../domain/product.dart';
import 'providers/products_providers.dart';

/// 商品详情页。通过路由 `/product/:id` 进入，id 由路由表解析后传入。
/// 数据来自 M4 练习写的 productProvider(id)（一个 family：按 id 缓存、自动释放）。
class ProductDetailPage extends ConsumerWidget {
  final int id;

  const ProductDetailPage({super.key, required this.id});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncProduct = ref.watch(productProvider(id));
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      // data 态用 SliverAppBar（带大图），所以这里不要普通 AppBar；
      // 其它态给一个普通 AppBar（自带返回按钮）。用 switch 对 AsyncValue 模式匹配（呼应 M2 sealed）。
      appBar: switch (asyncProduct) {
        AsyncData() => null,
        _ => AppBar(title: Text(l10n.productDetailTitle)),
      },
      body: asyncProduct.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => _ErrorBody(
          message: l10n.describeError(e),
          onRetry: () => ref.invalidate(productProvider(id)),
        ),
        data: (p) => _DetailView(product: p),
      ),
      // 只有拿到数据时才显示底部"加入购物车"栏。
      bottomNavigationBar: switch (asyncProduct) {
        AsyncData(:final value) => _AddToCartBar(product: value),
        _ => null,
      },
    );
  }
}

/// 详情主体：可折叠大图 + 信息区。
class _DetailView extends StatelessWidget {
  final Product product;
  const _DetailView({required this.product});

  @override
  Widget build(BuildContext context) {
    final p = product;
    return CustomScrollView(
      slivers: [
        // 顶部大图随滚动收缩（≈ 大图导航栏）。pinned: 收缩后标题栏吸顶。
        SliverAppBar(
          pinned: true,
          expandedHeight: 320,
          flexibleSpace: FlexibleSpaceBar(
            // 大图换成可左右滑动的多图轮播（写法呼应首页 HomeBanner）。
            // images 为空时退回用 thumbnail，保证至少有一张图。
            background: _DetailGallery(
              imageUrls: p.images.isNotEmpty ? p.images : [p.thumbnail],
            ),
          ),
        ),
        SliverToBoxAdapter(child: _buildInfo(context, p)),
      ],
    );
  }

  Widget _buildInfo(BuildContext context, Product p) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final l10n = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(p.title, style: text.titleLarge),
          const SizedBox(height: 12),
          // 价格：折后价（大、主色） + 原价（划线灰） + 折扣角标
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              // M12：金额交给 ARB 的 simpleCurrency 格式化——币种固定 USD（业务事实），
              // 千分位/小数点/符号位置跟语言走（en $1,234.50 · de 1.234,50 $）。
              Text(
                l10n.priceValue(p.discountedPrice),
                style: text.headlineSmall?.copyWith(
                  color: scheme.primary,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                l10n.priceValue(p.price),
                style: text.bodyMedium?.copyWith(
                  color: Colors.grey,
                  decoration:
                      TextDecoration.lineThrough, // 划线 ≈ NSAttributedString 删除线
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: scheme.errorContainer,
                  borderRadius: BorderRadius.circular(6),
                ),
                // percentPattern 接收的是小数，% 号放前放后、要不要空格由语言决定
                // （de "-9 %"、土耳其语甚至是 "%9"）。
                // 传**负数**而不是在 ARB 里写 "-{percent}"：阿语是 RTL，裸的 ASCII 连字符在段首
                // 会被双向算法判成从右往左，显示成 "9%-"；intl 格式化负数时会在负号前插一个
                // LRM（U+200E）把它钉在数字左边。符号也是格式的一部分，交给 locale。
                child: Text(
                  l10n.discountBadge(-p.discountPercentage / 100),
                  style: TextStyle(
                    color: scheme.onErrorContainer,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              const Icon(Icons.star, size: 16, color: Colors.amber),
              const SizedBox(width: 4),
              Text(l10n.ratingValue(p.rating)), // 4.5 / 4,5
              const SizedBox(width: 16),
              Icon(Icons.inventory_2_outlined, size: 16, color: scheme.outline),
              const SizedBox(width: 4),
              Text(l10n.stockCount(p.stock)),
              if (p.brand != null) ...[
                const SizedBox(width: 16),
                Icon(Icons.sell_outlined, size: 16, color: scheme.outline),
                const SizedBox(width: 4),
                Text(p.brand!),
              ],
            ],
          ),
          // 标签（可空）：有才显示。
          if (p.tags != null && p.tags!.isNotEmpty) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final t in p.tags!)
                  Chip(label: Text(t), visualDensity: VisualDensity.compact),
              ],
            ),
          ],
          const Divider(height: 32),
          Text(l10n.productDescription, style: text.titleMedium),
          const SizedBox(height: 8),
          Text(p.description, style: text.bodyMedium?.copyWith(height: 1.5)),
        ],
      ),
    );
  }
}

/// 详情页顶部大图轮播：可左右滑动看多张图 + 底部小圆点指示器。
/// 结构与首页 HomeBanner 基本一致（PageView + Positioned 圆点）；
/// 区别只是这里用 CachedNetworkImage（带磁盘缓存），并铺满整个 SliverAppBar 背景、不加圆角。
/// 要"记住当前第几页"来高亮圆点，是会变的状态 → StatefulWidget。
class _DetailGallery extends StatefulWidget {
  final List<String> imageUrls;

  const _DetailGallery({required this.imageUrls});

  @override
  State<_DetailGallery> createState() => _DetailGalleryState();
}

class _DetailGalleryState extends State<_DetailGallery> {
  // PageController 控制/监听翻页（≈ 你持有的 UIScrollView 控制器）。
  final _controller = PageController();
  int _current = 0;

  @override
  void dispose() {
    // initState/字段里 new 出来的控制器，必须在这里释放，否则泄漏。dispose() ≈ deinit。
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      // Stack ≈ SwiftUI ZStack：往背景上叠加子 view，配合 Positioned 做绝对定位。
      children: [
        PageView.builder(
          controller: _controller,
          itemCount: widget.imageUrls.length,
          // 翻页时更新当前页下标 → 重建 → 圆点高亮跟着变。
          onPageChanged: (i) => setState(() => _current = i),
          itemBuilder: (context, i) => CachedNetworkImage(
            imageUrl: widget.imageUrls[i],
            fit: BoxFit.cover,
            width: double.infinity,
            errorWidget: (c, u, e) => const ColoredBox(
              color: Color(0x11000000),
              child: Icon(Icons.image_outlined, size: 48),
            ),
          ),
        ),
        // 底部圆点指示器：只有多张图才显示。用 Positioned 绝对定位在轮播之上。
        if (widget.imageUrls.length > 1)
          Positioned(
            bottom: 12,
            left: 0,
            right: 0,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(widget.imageUrls.length, (i) {
                final active = i == _current;
                // AnimatedContainer：属性变化时自动补间动画（≈ UIView.animate）。
                return AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  width: active ? 18 : 6, // 当前页是长条，其余是小圆点
                  height: 6,
                  decoration: BoxDecoration(
                    color: active
                        ? Theme.of(context).colorScheme.primary
                        : Colors.white70,
                    borderRadius: BorderRadius.circular(3),
                  ),
                );
              }),
            ),
          ),
      ],
    );
  }
}

/// 底部"加入购物车"栏。M7 起真正写入全局 Cart provider；M9 加收藏♥按钮。
/// 改成 ConsumerWidget 是因为要 ref.read(cartProvider.notifier) 触发写操作。
class _AddToCartBar extends ConsumerStatefulWidget {
  final Product product;
  const _AddToCartBar({required this.product});

  @override
  ConsumerState<_AddToCartBar> createState() => _AddToCartBarState();
}

class _AddToCartBarState extends ConsumerState<_AddToCartBar> {
  bool _busy = false;

  Future<void> _perform(
    Future<void> Function() action, {
    String? message,
  }) async {
    if (_busy) return;
    setState(() => _busy = true);
    await runUiAction(context, action, successMessage: message);
    if (mounted) setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) {
    // watch 派生的 isFavoriteProvider(id)（family + 派生的组合）：
    // 收藏列表变化时，只有"这个商品"的收藏态变了才会触发这里重建。
    final isFav = ref.watch(isFavoriteProvider(widget.product.id));
    final l10n = AppLocalizations.of(context);

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
        child: Row(
          children: [
            // IconButton 自带"选中态"：isSelected + selectedIcon，
            // ≈ UIButton 的 isSelected 配 setImage(_:for: .selected)。
            // 好处是语义交给框架（无障碍朗读会带上选中状态），不用自己三元切 icon。
            IconButton(
              isSelected: isFav,
              icon: const Icon(Icons.favorite_border),
              selectedIcon: const Icon(Icons.favorite, color: Colors.redAccent),
              tooltip: isFav ? l10n.favoriteRemove : l10n.favoriteAdd,
              onPressed: _busy
                  ? null
                  : () => _perform(
                      () => ref
                          .read(favoritesProvider.notifier)
                          .toggle(widget.product),
                    ),
            ),
            Expanded(
              child: Text(
                l10n.priceValue(widget.product.discountedPrice),
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: Theme.of(context).colorScheme.primary,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            FilledButton.icon(
              onPressed: _busy
                  ? null
                  : () => _perform(
                      () => ref
                          .read(cartProvider.notifier)
                          .addProduct(widget.product),
                      message: l10n.addedToCart(widget.product.title),
                    ),
              icon: const Icon(Icons.add_shopping_cart),
              label: Text(l10n.addToCart),
            ),
          ],
        ),
      ),
    );
  }
}

/// 失败态：文案 + 重试。
class _ErrorBody extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _ErrorBody({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.cloud_off, size: 48, color: Colors.grey),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Text(message, textAlign: TextAlign.center),
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: onRetry,
            child: Text(AppLocalizations.of(context).retry),
          ),
        ],
      ),
    );
  }
}
