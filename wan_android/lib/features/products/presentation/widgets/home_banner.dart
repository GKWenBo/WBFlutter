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
  int _current = 0;

  @override
  void dispose() {
    // 和 iOS 一样：持有的控制器/订阅必须释放，否则泄漏。dispose() ≈ deinit。
    // 这是 StatefulWidget 最重要的纪律——凡是 initState/字段里 new 出来的控制器，都要在这里 dispose。
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      // AspectRatio 锁定 16:7 的横幅比例，布局不随图片加载前后高度跳动。
      aspectRatio: 16 / 7,
      child: Stack(
        // Stack ≈ SwiftUI ZStack / 往父 view 上叠加子 view，配合 Positioned 做绝对定位。
        children: [
          PageView.builder(
            controller: _controller,
            itemCount: widget.imageUrls.length,
            // 翻页时更新当前页下标 → 重建 → 圆点高亮跟着变。
            onPageChanged: (i) => setState(() => _current = i),
            itemBuilder: (context, i) => Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.network(
                  widget.imageUrls[i],
                  fit: BoxFit.cover,
                  width: double.infinity,
                  errorBuilder: (c, e, s) => const ColoredBox(
                    color: Color(0x11000000),
                    child: Icon(Icons.image_outlined, size: 40),
                  ),
                ),
              ),
            ),
          ),
          // 底部圆点指示器：用 Positioned 把它绝对定位在 PageView 之上。
          Positioned(
            bottom: 8,
            left: 0,
            right: 0,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(widget.imageUrls.length, (i) {
                final active = i == _current;
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
        ],
      ),
    );
  }
}
