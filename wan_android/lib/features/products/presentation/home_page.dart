import 'package:flutter/material.dart';

import 'widgets/category_chip.dart';
import 'widgets/home_banner.dart';
import 'widgets/product_card.dart';
import 'widgets/section_header.dart';

/// 首页（商品流）。
///
/// M1：用本地假数据搭出真实电商首页的样子。
/// （M2 把假数据换成真 model，M3 换成 DummyJSON 网络数据，M4 接 Riverpod 做加载/错误态。）
///
/// 本页只是"组装 + 展示"，没有自己的可变状态 → StatelessWidget。
/// 真正有状态的部分（Banner 当前页）被封装在 HomeBanner 里，不污染首页。
class HomePage extends StatelessWidget {
  const HomePage({super.key});

  // ---- 本地假数据（临时用 Dart 3 的"记录 record"承载，≈ Swift 的元组）----
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

  static const _products =
      <({String title, double price, String image, double rating})>[
        (
          title: 'iPhone 15 Pro 钛金属原色 256GB',
          price: 999.0,
          image: 'https://picsum.photos/seed/p1/300',
          rating: 4.9,
        ),
        (
          title: '无线降噪耳机 旗舰款',
          price: 249.5,
          image: 'https://picsum.photos/seed/p2/300',
          rating: 4.6,
        ),
        (
          title: '14 英寸轻薄笔记本电脑 M 系列芯片',
          price: 1599.0,
          image: 'https://picsum.photos/seed/p3/300',
          rating: 4.8,
        ),
        (
          title: '智能运动手表',
          price: 199.0,
          image: 'https://picsum.photos/seed/p4/300',
          rating: 4.3,
        ),
        (
          title: '4K 微单相机套机（含 18-55mm 镜头）',
          price: 899.0,
          image: 'https://picsum.photos/seed/p5/300',
          rating: 4.7,
        ),
        (
          title: '机械键盘 87 键',
          price: 79.9,
          image: 'https://picsum.photos/seed/p6/300',
          rating: 4.5,
        ),
      ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // SafeArea 避开刘海/灵动岛/底部条（≈ iOS 的 safeAreaInsets）。
      body: SafeArea(
        // CustomScrollView + Sliver：把"多段不同布局"拼成一条可滚动的列表，
        // 且整页只有一个滚动容器（性能好、滚动顺）。≈ UICollectionView 的多 section 组合布局。
        child: CustomScrollView(
          slivers: [
            // SliverToBoxAdapter：把一个"普通 Widget"塞进 Sliver 列表里。
            SliverToBoxAdapter(child: _buildSearchBar(context)),
            const SliverToBoxAdapter(child: SizedBox(height: 12)),
            const SliverToBoxAdapter(child: HomeBanner(imageUrls: _banners)),
            SliverToBoxAdapter(child: _buildCategoryRow()),
            SliverToBoxAdapter(
              child: SectionHeader(title: '为你推荐', onMore: () {}),
            ),

            // 商品网格：SliverGrid 是"可懒加载的网格"。
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 16),
              sliver: SliverGrid(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2, // 每行 2 列
                  mainAxisSpacing: 12, // 行间距
                  crossAxisSpacing: 12, // 列间距
                  childAspectRatio: 0.72, // 单元格宽/高比：<1 表示比正方形更高，给图+文留够空间
                ),
                // delegate ≈ UICollectionViewDataSource：按 index 造 cell，按需懒构建。
                delegate: SliverChildBuilderDelegate((context, i) {
                  final p = _products[i];
                  return ProductCard(
                    title: p.title,
                    price: p.price,
                    imageUrl: p.image,
                    rating: p.rating,
                    onTap: () {}, // M5 接路由后跳详情页
                  );
                }, childCount: _products.length),
              ),
            ),
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

  /// 横向滚动的分类入口。
  /// 关键点：横向 ListView 必须有"有界高度"，所以外面套一个 SizedBox 固定高度。
  Widget _buildCategoryRow() {
    return SizedBox(
      // 高度要 ≥ 内容实际需要的高度，否则底部会出现 RenderFlex 溢出警示条。
      // 这里内容（头像52 + 间距6 + 文字 + 内外两层 padding）约 106，给 112 留点余量。
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
