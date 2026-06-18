import 'package:flutter/material.dart';

/// 分类页。M6 会接入 DummyJSON 的分类数据。现在先占位。
class CategoriesPage extends StatelessWidget {
  const CategoriesPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('分类')),
      body: const Center(
        child: Text('分类 · 建设中', style: TextStyle(fontSize: 20)),
      ),
    );
  }
}
