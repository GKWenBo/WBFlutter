import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../domain/product.dart';
import 'providers/products_providers.dart';
import 'widgets/category_chip.dart';
import 'widgets/home_banner.dart';
import 'widgets/product_card.dart';
import 'widgets/section_header.dart';

/// 首页（商品流）。
///
/// M4：取数逻辑搬到了 Riverpod 的 ProductList provider，页面只负责"订阅 + 渲染"。
/// 用 ConsumerStatefulWidget 是因为还要持有 ScrollController 做上拉分页（需要 dispose）。
class HomePage extends ConsumerStatefulWidget {
  const HomePage({super.key});

  @override
  ConsumerState<HomePage> createState() => _HomePageState();
}

class _HomePageState extends ConsumerState<HomePage> {
  // Banner / 分类入口仍是本地假数据（M6 接分类接口时再换）。
  static const _banners = [
    'https://picsum.photos/seed/banner1/800/350',
    'https://picsum.photos/seed/banner2/800/350',
    'https://picsum.photos/seed/banner3/800/350',
  ];

  static const _categories = <({IconData icon, String label})>[
    (icon: Icons.phone_iphone, label: '手机'),
    (icon: Icons.laptop_mac, label: '电脑'),
    (icon: Icons.watch, label: '手表'),
    (icon: Icons.headphones, label: '耳机'),
    (icon: Icons.camera_alt, label: '相机'),
    (icon: Icons.videogame_asset, label: '游戏'),
  ];

  final _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.dispose(); // 持有的控制器要释放（≈ deinit）
    super.dispose();
  }

  // 滚动到接近底部时，触发"加载更多"。
  void _onScroll() {
    final pos = _scrollController.position;
    if (pos.pixels >= pos.maxScrollExtent - 300) {
      // ref.read：在回调里取一次 notifier，不订阅。
      ref.read(productListProvider.notifier).loadMore();
    }
  }

  @override
  Widget build(BuildContext context) {
    // ref.watch：订阅 provider，状态一变（loading→data→…）就重建本页（≈ 订阅 @Published）。
    final asyncProducts = ref.watch(productListProvider);

    return Scaffold(
      body: SafeArea(
        child: RefreshIndicator(
          // 下拉刷新：ref.refresh 重建 provider→重新取第一页；返回的 Future 让转圈持续到加载完成。
          onRefresh: () => ref.refresh(productListProvider.future),
          child: CustomScrollView(
            controller: _scrollController,
            // 让内容很少时也能下拉（否则 RefreshIndicator 触发不了）。
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              SliverToBoxAdapter(child: _buildSearchBar(context)),
              const SliverToBoxAdapter(child: SizedBox(height: 12)),
              const SliverToBoxAdapter(child: HomeBanner(imageUrls: _banners)),
              SliverToBoxAdapter(child: _buildCategoryRow()),
              SliverToBoxAdapter(
                child: SectionHeader(title: '为你推荐', onMore: () {}),
              ),

              // 三态渲染：AsyncValue.when 把 loading/error/data 三种情况一次写清。
              // 这里每个分支返回"一组 sliver"，用 ...展开（spread）拼进 slivers。
              ...asyncProducts.when(
                loading: () => [_loadingSliver()],
                error: (e, _) => [_errorSliver('$e')],
                data: (products) => [
                  _productGrid(products),
                  // 还有下一页就显示底部"加载更多"转圈。
                  if (ref.read(productListProvider.notifier).hasMore)
                    _footerLoadingSliver(),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _productGrid(List<Product> products) {
    return SliverPadding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 16),
      sliver: SliverGrid(
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: 0.72,
        ),
        delegate: SliverChildBuilderDelegate((context, i) {
          final p = products[i];
          return ProductCard(
            title: p.title,
            price: p.discountedPrice,
            imageUrl: p.thumbnail,
            rating: p.rating,
            // 点卡片 → push 到详情页，把商品 id 放进路径。
            onTap: () => context.push('/product/${p.id}'),
          );
        }, childCount: products.length),
      ),
    );
  }

  Widget _loadingSliver() => const SliverToBoxAdapter(
    child: Padding(
      padding: EdgeInsets.all(48),
      child: Center(child: CircularProgressIndicator()),
    ),
  );

  Widget _footerLoadingSliver() => const SliverToBoxAdapter(
    child: Padding(
      padding: EdgeInsets.symmetric(vertical: 24),
      child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
    ),
  );

  Widget _errorSliver(String message) {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.cloud_off, size: 48, color: Colors.grey),
              const SizedBox(height: 12),
              Text(message, textAlign: TextAlign.center),
              const SizedBox(height: 16),
              ElevatedButton(
                // 重试：让 provider 失效→重建→重新取数。
                onPressed: () => ref.invalidate(productListProvider),
                child: const Text('重试'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 顶部搜索框：点一下进搜索页（它本身不输入，真正输入在 SearchPage）。
  Widget _buildSearchBar(BuildContext context) {
    final hint = Theme.of(context).hintColor;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      // GestureDetector 让整条搜索框可点（≈ 给 view 加 tap 手势）。
      child: GestureDetector(
        onTap: () => context.push('/search'),
        child: Container(
          height: 40,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            children: [
              Icon(Icons.search, size: 20, color: hint),
              const SizedBox(width: 8),
              Text('搜索商品', style: TextStyle(color: hint)),
            ],
          ),
        ),
      ),
    );
  }

  /// 横向滚动的分类入口。横向 ListView 必须有"有界高度"，故套 SizedBox。
  Widget _buildCategoryRow() {
    return SizedBox(
      height: 112,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        itemCount: _categories.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, i) {
          final c = _categories[i];
          return CategoryChip(icon: c.icon, label: c.label, onTap: () {});
        },
      ),
    );
  }
}
