import 'package:flutter/foundation.dart';

import '../../../shared/api/product_api.dart';
import '../../../shared/models/product.dart';

/// 场景①状态层：异步三态 + 分页，从页面 State 搬进 ChangeNotifier。
/// v0 时代这坨状态住在页面里，只能隔着 widget 测试戳；现在是纯 Dart
/// 对象——直接 new 出来断言。**可测性是搬家的最大红利**（≈ 把逻辑从
/// UIViewController 搬进 ViewModel 后终于能写单测了）。
class ProductListModel extends ChangeNotifier {
  ProductListModel(this._api);

  final ProductApi _api;

  final List<Product> _items = [];
  List<Product> get items => List.unmodifiable(_items);

  bool _loading = false;
  bool get loading => _loading;

  bool _loadingMore = false;
  bool get loadingMore => _loadingMore;

  String? _error;
  String? get error => _error;

  bool _hasMore = true;
  bool get hasMore => _hasMore;

  int _skip = 0;

  /// 模型侧的 mounted：页面 pop 后 provider 会 dispose 本模型，
  /// 但在途的请求还会回来——回来后再 notifyListeners 就撞
  /// "used after being disposed"。守卫一下（≈ weak self 判空）。
  bool _disposed = false;

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  Future<void> loadFirst() async {
    _loading = true;
    _error = null;
    _notify();
    try {
      final page = await _api.fetchProducts(skip: 0);
      _items
        ..clear()
        ..addAll(page.products);
      _skip = page.products.length;
      _hasMore = page.hasMore;
      _loading = false;
      _notify();
    } catch (e) {
      _loading = false;
      _error = '加载失败：$e';
      _notify();
    }
  }

  Future<void> loadMore() async {
    if (_loadingMore || !_hasMore) return; // 防重，同 v0
    _loadingMore = true;
    _notify();
    try {
      final page = await _api.fetchProducts(skip: _skip);
      _items.addAll(page.products);
      _skip += page.products.length;
      _hasMore = page.hasMore;
    } catch (_) {
      // 加载更多失败不打断已有列表（v0 语义原样保留）
    } finally {
      _loadingMore = false;
      _notify();
    }
  }
}
