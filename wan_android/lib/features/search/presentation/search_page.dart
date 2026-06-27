import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../products/presentation/widgets/product_grid.dart';
import 'providers/search_providers.dart';

/// 搜索页：输入框 + 防抖 + 结果网格。
/// 用 ConsumerStatefulWidget 是因为要持有 TextEditingController 和防抖 Timer（都要 dispose）。
class SearchPage extends ConsumerStatefulWidget {
  const SearchPage({super.key});

  @override
  ConsumerState<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends ConsumerState<SearchPage> {
  final _controller = TextEditingController();

  // 防抖计时器（≈ 可取消的 DispatchWorkItem）。
  Timer? _debounce;

  // 真正用于查询的关键词：只有"停止输入 400ms"后才更新它，避免每敲一个字就请求。
  String _query = '';

  @override
  void dispose() {
    _debounce?.cancel(); // 取消未触发的计时器
    _controller.dispose(); // 释放输入框控制器
    super.dispose();
  }

  void _onChanged(String text) {
    // 防抖核心：每次输入都取消上一个计时器，重新计时；
    // 只有连续 400ms 没再输入，才把文字提交为真正的查询词。
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () {
      setState(() => _query = text);
    });
  }

  @override
  Widget build(BuildContext context) {
    // 关键词为空时不去 watch 结果，直接显示提示。
    final hasQuery = _query.trim().isNotEmpty;

    return Scaffold(
      appBar: AppBar(
        title: TextField(
          controller: _controller,
          autofocus: true,
          textInputAction: TextInputAction.search,
          decoration: const InputDecoration(
            hintText: '搜索商品',
            border: InputBorder.none,
          ),
          onChanged: _onChanged,
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.clear),
            onPressed: () {
              _controller.clear();
              _debounce?.cancel();
              setState(() => _query = '');
            },
          ),
        ],
      ),
      body: !hasQuery
          ? const Center(child: Text('输入关键词搜索商品'))
          : ref
                .watch(searchResultsProvider(_query))
                .when(
                  loading: () =>
                      const Center(child: CircularProgressIndicator()),
                  error: (e, _) => Center(child: Text('$e')),
                  data: (products) => ProductGrid(
                    products: products,
                    emptyHint: '没有找到与"$_query"相关的商品',
                  ),
                ),
    );
  }
}
