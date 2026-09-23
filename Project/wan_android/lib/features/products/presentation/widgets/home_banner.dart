import 'package:flutter/material.dart';

/// 首页顶部 Banner：可左右滑动的图片轮播 + 底部小圆点指示器。
///
/// PageView ≈ iOS 的 UIPageViewController / 开了分页的 UIScrollView。
/// 因为要"记住当前在第几页"来高亮对应圆点，是会变的状态 → StatefulWidget。
class HomeBanner extends StatefulWidget {
  final List<String> imageUrls;

  const HomeBanner({super.key, required this.imageUrls});

  @override
  State<HomeBanner> createState() => _HomeBannerState();
}

class _HomeBannerState extends State<HomeBanner> {
  // PageController 控制/监听翻页（≈ 你持有的 UIScrollView 控制器）。
  final _controller = PageController();

  // M13 性能优化：当前页下标从 `int _current` + setState 改成 ValueNotifier。
  // 原因见下方 build 的注释——setState 会重建整个 build（含 PageView），
  // 而翻页时真正需要重画的只有底部那几个圆点。ValueNotifier + ValueListenableBuilder
  // 把"变化的通知"精确送到只订阅它的那一小块 UI，PageView 完全不参与重建。
  // 类比 iOS：≈ 一个 Combine 的 CurrentValueSubject，只有订阅它的视图才刷新。
  final _current = ValueNotifier<int>(0);

  @override
  void dispose() {
    // 和 iOS 一样：持有的控制器/订阅必须释放，否则泄漏。dispose() ≈ deinit。
    // 这是 StatefulWidget 最重要的纪律——凡是 initState/字段里 new 出来的控制器/Notifier，都要在这里 dispose。
    _controller.dispose();
    _current.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // M13：整个 Banner 用 RepaintBoundary 包住，给它单独一层光栅化图层。
    // 底部圆点每 200ms 补间动画会持续触发重绘；有了这道边界，重绘被"关"在 Banner 内部，
    // 不会把上面搜索框、下面整屏商品网格一起拖去重画。
    // DevTools 打开 "Highlight repaints"（重绘彩虹）就能直观看到边界内外的隔离效果。
    // 类比 iOS：≈ 给频繁动画的图层设 shouldRasterize / 独立 CALayer，隔离脏区。
    return RepaintBoundary(
      child: AspectRatio(
        // AspectRatio 锁定 16:7 的横幅比例，布局不随图片加载前后高度跳动。
        aspectRatio: 16 / 7,
        child: Stack(
          // Stack ≈ SwiftUI ZStack / 往父 view 上叠加子 view，配合 Positioned 做绝对定位。
          children: [
            PageView.builder(
              controller: _controller,
              itemCount: widget.imageUrls.length,
              // 翻页时只更新 Notifier 的值——不 setState，所以 build 不重跑、PageView 不重建。
              onPageChanged: (i) => _current.value = i,
              itemBuilder: (context, i) {
                // M13 练习：给网络图限「解码尺寸」，避免把远大于显示区的原图整张解进内存。
                // cacheWidth 的单位是【物理像素】：显示宽度(逻辑像素) × devicePixelRatio。
                // 例：banner 在 3x 手机上显示约 375pt 宽 → 解码到 ~1125px 就够清晰，
                // 而不是把 picsum 给的原图按原分辨率塞进内存。DevTools 的
                // Highlight Oversized Images 打开后，超配的图会被标红——加了这行就不再红。
                // 类比 iOS：≈ 用 ImageIO/CGImageSourceCreateThumbnailAtIndex 生成缩略图，
                // 而不是把大图整张 decode 成 UIImage 再缩放显示。
                final dpr = MediaQuery.devicePixelRatioOf(context);
                final cacheW = (MediaQuery.sizeOf(context).width * dpr).round();
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.network(
                      widget.imageUrls[i],
                      fit: BoxFit.cover,
                      width: double.infinity,
                      cacheWidth: cacheW, // 只按需解码，省内存 + 减轻 Raster 负担
                      errorBuilder: (c, e, s) => const ColoredBox(
                        color: Color(0x11000000),
                        child: Icon(Icons.image_outlined, size: 40),
                      ),
                    ),
                  ),
                );
              },
            ),
            // 底部圆点指示器：用 Positioned 把它绝对定位在 PageView 之上。
            Positioned(
              bottom: 8,
              left: 0,
              right: 0,
              // ValueListenableBuilder：只有它的 builder 会在 _current 变化时重跑，
              // 这就是"收窄重建范围"的落地——重建半径从整个 Banner 缩到这一行圆点。
              child: ValueListenableBuilder<int>(
                valueListenable: _current,
                builder: (context, current, _) => Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(widget.imageUrls.length, (i) {
                    final active = i == current;
                    // AnimatedContainer：属性变化时自动补间动画（≈ UIView.animate），白送的丝滑效果。
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
            ),
          ],
        ),
      ),
    );
  }
}
