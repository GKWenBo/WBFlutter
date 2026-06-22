import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

/// 商品卡片——首页商品网格的单元格，是最典型的可复用组件。
/// 角色 ≈ 你的 UICollectionViewCell（但声明式、无需注册/复用标识符，框架负责回收）。
class ProductCard extends StatelessWidget {
  final String title;
  final double price;
  final String imageUrl;
  final double rating;
  final VoidCallback? onTap;

  const ProductCard({
    super.key,
    required this.title,
    required this.price,
    required this.imageUrl,
    required this.rating,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      margin: EdgeInsets.zero, // 卡片间距交给外层 Grid 统一控制，避免双重边距
      clipBehavior: Clip.antiAlias, // 让圆角连图片一起裁切（否则图片方角会盖过卡片圆角）
      child: InkWell(
        onTap: onTap,
        child: Column(
          // 子项横向撑满卡片宽度（≈ Auto Layout 把子 view 左右贴边）。
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 1) 商品图：用 Expanded 占据"卡片高度里除文字外的剩余空间"。
            //    这是防溢出的关键——文字区按内容取高，图片自动吃掉剩下的，永远不会撑爆。
            //    （Expanded ≈ Auto Layout 里 hugging 低、优先被拉伸的那个 view。）
            Expanded(
              child: CachedNetworkImage(
                imageUrl: imageUrl,
                fit: BoxFit
                    .cover, // 等比裁切填满（≈ contentMode = .scaleAspectFill + clipsToBounds）
                width: double.infinity,
                // 加载中占位（≈ 给 UIImageView 设 placeholder）。CachedNetworkImage 会缓存到内存+磁盘，
                // 同一张图二次出现直接命中缓存，不再走网络。
                placeholder: (context, url) => const ColoredBox(
                  color: Color(0x11000000),
                  child: Center(
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
                // 加载失败的兜底。
                errorWidget: (context, url, error) => const ColoredBox(
                  color: Color(0x11000000),
                  child: Icon(Icons.broken_image_outlined, size: 40),
                ),
              ),
            ),
            // 2) 文字区
            Padding(
              padding: const EdgeInsets.all(8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start, // 文字区左对齐
                children: [
                  Text(
                    title,
                    maxLines: 2, // 最多两行
                    overflow: TextOverflow.ellipsis, // 超出显示省略号——防止长标题撑爆卡片
                    style: const TextStyle(fontSize: 14, height: 1.2),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Text(
                        '\$${price.toStringAsFixed(2)}',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: scheme.primary, // 价格用主题主色（电商橙）
                        ),
                      ),
                      const Spacer(),
                      const Icon(Icons.star, size: 14, color: Colors.amber),
                      const SizedBox(width: 2),
                      Text(
                        rating.toStringAsFixed(1),
                        style: const TextStyle(fontSize: 12),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
