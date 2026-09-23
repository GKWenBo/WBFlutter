import 'package:get/get.dart';

import '../../../shared/api/product_api.dart';
import '../../../shared/models/product.dart';

/// 场景①：三态 + 分页，**手动挡**（GetBuilder + update()）。字段全是普通
/// Dart 字段，改完手动 `update([ids])` 通知——本质是"把 setState 从页面挪进
/// controller"，零 Rx 开销，重建范围靠 id 分组手工指定：
/// - `'list'`：body（三态视图 + 列表本体）
/// - `'footer'`：底部加载更多指示器
/// loadingMore 翻转只刷 footer 不刷整列表——对照 v2 的 buildWhen 干的是
/// 同一件事，一个靠比对状态字段，一个靠作者手工点名。
///
/// 注意：**id 分组是隔离的**——无参 `update()` 只刷无 id 的 GetBuilder，
/// 刷不到带 id 的（新手高频坑），所以这里所有通知都显式带 ids。
class ProductListGetxController extends GetxController {
  ProductListGetxController(this.api);

  final ProductApi api;

  final List<Product> items = [];
  bool loading = false;
  bool loadingMore = false;
  String? error;
  bool hasMore = true;
  int _skip = 0;

  @override
  void onInit() {
    super.onInit();
    loadFirst(); // Get.put / GetBuilder(init:) 创建时自动开载（≈ initState 首载）
  }

  /// isClosed 守卫：GetX 版的 `_disposed`。v1 手写、v2 框架接管、v3 框架
  /// 给了标志位但**判断还得自己调**——页面 pop 删 controller 后在途请求
  /// 回来，不守卫就撞 "used after being disposed"。
  void _safeUpdate(List<Object> ids) {
    if (!isClosed) update(ids);
  }

  Future<void> loadFirst() async {
    loading = true;
    error = null;
    _safeUpdate(['list', 'footer']);
    try {
      final page = await api.fetchProducts(skip: 0);
      items
        ..clear()
        ..addAll(page.products);
      _skip = page.products.length;
      hasMore = page.hasMore;
      loading = false;
      _safeUpdate(['list', 'footer']);
    } catch (e) {
      loading = false;
      error = '加载失败：$e';
      _safeUpdate(['list', 'footer']);
    }
  }

  Future<void> loadMore() async {
    if (loadingMore || !hasMore) return; // 布尔防重入（v1 同款；对照 v2 droppable）
    loadingMore = true;
    _safeUpdate(['footer']); // 只有 footer 需要知道"正在加载更多"
    try {
      final page = await api.fetchProducts(skip: _skip);
      items.addAll(page.products);
      _skip += page.products.length;
      hasMore = page.hasMore;
      loadingMore = false;
      _safeUpdate(['list', 'footer']);
    } catch (_) {
      // 加载更多失败不打断已有列表（v0/v1/v2 语义原样保留）
      loadingMore = false;
      _safeUpdate(['footer']);
    }
  }
}
