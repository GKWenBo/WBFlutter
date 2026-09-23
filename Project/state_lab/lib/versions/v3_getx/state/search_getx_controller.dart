import 'package:get/get.dart';

import '../../../shared/api/product_api.dart';
import '../../../shared/models/product.dart';

/// 场景⑤：输入流处理，自动挡 + **workers**。GetX 的 `debounce()` worker
/// 订阅一个 Rx，静默期结束才触发回调——替掉了 v1 手写的 Timer。
/// 但注意缺口：**GetX 没有 restartable/switchMap**，"丢过期响应"仍要手写
/// 请求序号（v1 同款）——对照 v2 一个 EventTransformer 连防抖带丢过期
/// 一锅端。workers 家族速查：debounce（防抖）/ interval（节流）/
/// ever（每次变化）/ once（只第一次）。
class SearchGetxController extends GetxController {
  SearchGetxController(
    this._api, {
    this.debounceDuration = const Duration(milliseconds: 400),
  });

  final ProductApi _api;

  /// 可注入的防抖时长（生产默认 400ms=设计文档冻结值；测试调小提速）。
  final Duration debounceDuration;

  final RxString query = ''.obs;
  final RxList<Product> results = <Product>[].obs;
  final RxBool loading = false.obs;
  final RxnString error = RxnString();

  int _seq = 0;
  Worker? _worker;

  @override
  void onInit() {
    super.onInit();
    // Rx 相同值不重发（内建去重），所以连打同一个词不会触发多枪。
    _worker = debounce<String>(query, (_) => _search(), time: debounceDuration);
  }

  @override
  void onClose() {
    _worker?.dispose(); // worker 不随 controller 自动销毁，手动关（高频坑）
    super.onClose();
  }

  /// TextField.onChanged 直连这里：只改 Rx，防抖由 worker 接管。
  void onQueryChanged(String text) => query.value = text;

  Future<void> retry() => _search();

  Future<void> _search() async {
    final q = query.value.trim();
    if (q.isEmpty) {
      results.clear();
      error.value = null;
      loading.value = false;
      return;
    }
    final seq = ++_seq; // 手写序号丢过期：GetX 没有 switchMap，这活省不掉
    loading.value = true;
    error.value = null;
    try {
      final r = await _api.searchProducts(q);
      if (isClosed || seq != _seq) return; // 过期响应，扔
      results.assignAll(r);
      loading.value = false;
    } catch (e) {
      if (isClosed || seq != _seq) return;
      loading.value = false;
      error.value = '搜索失败：$e';
    }
  }
}
