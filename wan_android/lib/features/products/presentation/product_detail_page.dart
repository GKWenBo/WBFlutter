import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../cart/presentation/providers/cart_providers.dart';
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

    return Scaffold(
      // data 态用 SliverAppBar（带大图），所以这里不要普通 AppBar；
      // 其它态给一个普通 AppBar（自带返回按钮）。用 switch 对 AsyncValue 模式匹配（呼应 M2 sealed）。
      appBar: switch (asyncProduct) {
        AsyncData() => null,
        _ => AppBar(title: const Text('商品详情')),
      },
      body: asyncProduct.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => _ErrorBody(
          message: '$e',
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
              Text(
                '\$${p.discountedPrice.toStringAsFixed(2)}',
                style: text.headlineSmall?.copyWith(
                  color: scheme.primary,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '\$${p.price.toStringAsFixed(2)}',
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
                child: Text(
                  '-${p.discountPercentage.toStringAsFixed(0)}%',
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
              Text(p.rating.toStringAsFixed(1)),
              const SizedBox(width: 16),
              Icon(Icons.inventory_2_outlined, size: 16, color: scheme.outline),
              const SizedBox(width: 4),
              Text('库存 ${p.stock}'),
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
          Text('商品介绍', style: text.titleMedium),
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

/// 底部"加入购物车"栏。M7 起真正写入全局 Cart provider。
/// 改成 ConsumerWidget 是因为要 ref.read(cartProvider.notifier) 触发写操作。
class _AddToCartBar extends ConsumerWidget {
  final Product product;
  const _AddToCartBar({required this.product});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
        child: Row(
          children: [
            Expanded(
              child: Text(
                '\$${product.discountedPrice.toStringAsFixed(2)}',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: Theme.of(context).colorScheme.primary,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            FilledButton.icon(
              onPressed: () {
                // ref.read(...).notifier：在事件回调里取一次 notifier 调用方法（写操作用 read，不用 watch）。
                ref.read(cartProvider.notifier).addProduct(product);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('已加入购物车：${product.title}'),
                    duration: const Duration(seconds: 1),
                  ),
                );
              },
              icon: const Icon(Icons.add_shopping_cart),
              label: const Text('加入购物车'),
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
          ElevatedButton(onPressed: onRetry, child: const Text('重试')),
        ],
      ),
    );
  }
}
