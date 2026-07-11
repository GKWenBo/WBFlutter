import 'package:flutter/material.dart';

/// AppBar 购物车角标按钮（纯展示：数量由外部传入）。
/// 类比 iOS：UITabBarItem.badgeValue，但这里是个普通组合 Widget。
/// 设计文档：它在所有页面常驻，是观察"谁在监听、谁被重建"的最佳窗口。
class CartIconButton extends StatelessWidget {
  const CartIconButton({super.key, required this.count, required this.onPressed});

  final int count;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: '购物车',
      onPressed: onPressed,
      icon: Badge.count(
        count: count,
        isLabelVisible: count > 0,
        child: const Icon(Icons.shopping_cart_outlined),
      ),
    );
  }
}
