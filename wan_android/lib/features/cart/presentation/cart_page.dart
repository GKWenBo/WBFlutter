import 'package:flutter/material.dart';

/// 购物车页。M7 会做成完整购物车（增删改数量、算总价、本地持久化）。现在先占位。
class CartPage extends StatelessWidget {
  const CartPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('购物车')),
      body: const Center(
        child: Text('购物车 · 建设中', style: TextStyle(fontSize: 20)),
      ),
    );
  }
}
