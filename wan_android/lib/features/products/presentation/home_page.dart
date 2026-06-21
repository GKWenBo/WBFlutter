import 'package:flutter/material.dart';

import '../data/product_list_response.dart';
import '../data/products_repository.dart';
import 'widgets/category_chip.dart';
import 'widgets/home_banner.dart';
import 'widgets/product_card.dart';
import 'widgets/section_header.dart';

/// 首页（商品流）。
///
/// M3：商品数据改为来自真实网络（DummyJSON）。
/// 因为要持有"请求的 Future"并能"重试"（会变的状态），所以升级为 StatefulWidget。
/// （M4 会把取数逻辑搬到 Riverpod，这个页面又能瘦回 Stateless 风格。）
class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  // Banner / 分类入口暂时仍是本地假数据（M6 接分类接口时再换）。
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

  final _repo = ProductsRepository();

  // 持有请求的 Future。关键：在 initState 里只建一次，
  // 绝不能写在 build 里——否则每次重建都会重新发请求（FutureBuilder 最经典的坑）。
  late Future<ProductListResponse> _future;

  @override
  void initState() {
    super.initState();
    // initState ≈ viewDidLoad：页面首次创建时发起首屏请求。
    _future = _repo.fetchProducts(limit: 20, skip: 0);
  }

  // 出错重试：重新建一个 Future 并触发重建。
  void _reload() {
    setState(() {
      _future = _repo.fetchProducts(limit: 20, skip: 0);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(child: _buildSearchBar(context)),
            const SliverToBoxAdapter(child: SizedBox(height: 12)),
            const SliverToBoxAdapter(child: HomeBanner(imageUrls: _banners)),
            SliverToBoxAdapter(child: _buildCategoryRow()),
            SliverToBoxAdapter(
              child: SectionHeader(title: '为你推荐', onMore: () {}),
            ),

            // FutureBuilder 把"一次异步请求"绑定到 UI：根据 snapshot 渲染三态。
            // 它的 builder 这里返回的是 Sliver，所以能直接放进 slivers 列表。
            FutureBuilder<ProductListResponse>(
              future: _future,
              builder: (context, snapshot) {
                // 1) 进行中
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const SliverToBoxAdapter(
                    child: Padding(
                      padding: EdgeInsets.all(48),
                      child: Center(child: CircularProgressIndicator()),
                    ),
                  );
                }
                // 2) 失败
                if (snapshot.hasError) {
                  return SliverToBoxAdapter(
                    child: _buildError('${snapshot.error}'),
                  );
                }
                // 3) 成功
                final products = snapshot.data!.products;
                return SliverPadding(
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 16),
                  sliver: SliverGrid(
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
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
                        onTap: () {}, // M5 接路由后跳详情页
                      );
                    }, childCount: products.length),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  /// 失败态：图标 + 错误文案 + 重试按钮。
  Widget _buildError(String message) {
    return Padding(
      padding: const EdgeInsets.all(40),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cloud_off, size: 48, color: Colors.grey),
            const SizedBox(height: 12),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            ElevatedButton(onPressed: _reload, child: const Text('重试')),
          ],
        ),
      ),
    );
  }

  /// 顶部假搜索框（M6 才做成真正可输入/可搜索的）。
  Widget _buildSearchBar(BuildContext context) {
    final hint = Theme.of(context).hintColor;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
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
