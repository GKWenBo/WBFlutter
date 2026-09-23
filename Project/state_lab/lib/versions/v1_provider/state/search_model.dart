import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../shared/api/product_api.dart';
import '../../../shared/models/product.dart';

/// 场景⑤状态层：防抖 + 序号丢过期，整个从页面搬进模型。
/// 页面瘦成"转发输入 + 展示状态"；防抖逻辑第一次变得可单测
/// （fake_async 拨表针，不用真等 400ms）。
class SearchModel extends ChangeNotifier {
  SearchModel(this._api, {this.debounce = const Duration(milliseconds: 400)});

  final ProductApi _api;

  /// 可注入的防抖时长（生产默认 400ms=设计文档冻结值；测试可调零）。
  final Duration debounce;

  Timer? _timer;
  int _requestSeq = 0;
  bool _disposed = false;

  List<Product> _results = [];
  List<Product> get results => List.unmodifiable(_results);

  bool _loading = false;
  bool get loading => _loading;

  String? _error;
  String? get error => _error;

  String _lastQuery = '';
  String get lastQuery => _lastQuery;

  @override
  void dispose() {
    _disposed = true;
    _timer?.cancel(); // 页面没了 Timer 还开火 = 悬垂闭包，S0 讲过
    super.dispose();
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  /// TextField.onChanged 直连这里：每次输入推倒重来——防抖。
  void onQueryChanged(String text) {
    _timer?.cancel();
    _timer = Timer(debounce, () => _search(text.trim()));
  }

  Future<void> retry() => _search(_lastQuery);

  Future<void> _search(String query) async {
    _lastQuery = query;
    if (query.isEmpty) {
      _results = [];
      _error = null;
      _loading = false;
      _notify();
      return;
    }
    final seq = ++_requestSeq;
    _loading = true;
    _error = null;
    _notify();
    try {
      final results = await _api.searchProducts(query);
      if (_disposed || seq != _requestSeq) return; // 过期响应，扔
      _results = results;
      _loading = false;
      _notify();
    } catch (e) {
      if (_disposed || seq != _requestSeq) return;
      _loading = false;
      _error = '搜索失败：$e';
      _notify();
    }
  }
}
