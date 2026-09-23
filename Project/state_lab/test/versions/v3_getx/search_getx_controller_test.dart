import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:state_lab/shared/api/product_api.dart';
import 'package:state_lab/shared/models/product.dart';
import 'package:state_lab/versions/v3_getx/state/search_getx_controller.dart';

const _p1 = Product(id: 1, title: 'phone A', description: 'a', price: 1, thumbnail: 'x', rating: 4);
const _p2 = Product(id: 2, title: 'phone B', description: 'b', price: 2, thumbnail: 'x', rating: 4);

/// 记录每次搜索词的假 API（即时返回 _p1）。
class _RecordingApi implements ProductApi {
  final queries = <String>[];

  @override
  Future<List<Product>> searchProducts(String query) async {
    queries.add(query);
    return const [_p1];
  }

  @override
  Future<ProductPage> fetchProducts({required int skip, int limit = ProductApi.pageSize}) =>
      throw UnimplementedError();
}

/// 请求挂起、由测试手动完成的假 API——模拟"慢请求"。
class _CompleterApi implements ProductApi {
  final pending = <Completer<List<Product>>>[];

  @override
  Future<List<Product>> searchProducts(String query) {
    final c = Completer<List<Product>>();
    pending.add(c);
    return c.future;
  }

  @override
  Future<ProductPage> fetchProducts({required int skip, int limit = ProductApi.pageSize}) =>
      throw UnimplementedError();
}

/// debounce worker 用真 Timer——测试注入 50ms 提速（生产默认 400ms）。
const _debounce = Duration(milliseconds: 50);

SearchGetxController _make(ProductApi api) {
  final c = SearchGetxController(api, debounceDuration: _debounce);
  c.onInit(); // 直接 new 不走 Get.put，生命周期手动触发（worker 在 onInit 挂上）
  return c;
}

void main() {
  group('SearchGetxController', () {
    test('debounce worker：静默期内连续输入，只发最后一枪', () async {
      final api = _RecordingApi();
      final c = _make(api);
      c.onQueryChanged('p');
      await Future<void>.delayed(const Duration(milliseconds: 20));
      c.onQueryChanged('ph');
      await Future<void>.delayed(const Duration(milliseconds: 20));
      c.onQueryChanged('phone');
      await Future<void>.delayed(const Duration(milliseconds: 120));
      expect(api.queries, ['phone']); // 前两枪被 worker 掐灭
      expect(c.results.length, 1);
      expect(c.loading.value, isFalse);
      c.onClose();
    });

    test('空查询：清空结果、不发请求', () async {
      final api = _RecordingApi();
      final c = _make(api);
      c.onQueryChanged('   ');
      await Future<void>.delayed(const Duration(milliseconds: 120));
      expect(api.queries, isEmpty);
      expect(c.results, isEmpty);
      expect(c.error.value, isNull);
      c.onClose();
    });

    test('慢请求过期丢弃：手写序号（GetX 没有 switchMap，这活省不掉）', () async {
      final api = _CompleterApi();
      final c = _make(api);
      c.onQueryChanged('ph');
      await Future<void>.delayed(const Duration(milliseconds: 80)); // 第一枪已发，挂起
      c.onQueryChanged('phone');
      await Future<void>.delayed(const Duration(milliseconds: 80)); // 第二枪已发，挂起
      expect(api.pending.length, 2);

      api.pending[1].complete(const [_p2]); // 新请求先回
      await Future<void>.delayed(Duration.zero);
      expect(c.results.single.id, 2);

      api.pending[0].complete(const [_p1]); // 旧请求慢吞吞回来
      await Future<void>.delayed(Duration.zero);
      expect(c.results.single.id, 2); // 仍是新结果：过期响应被序号拦下
      c.onClose();
    });

    test('请求失败：error 落地', () async {
      final api = _CompleterApi();
      final c = _make(api);
      c.onQueryChanged('phone');
      await Future<void>.delayed(const Duration(milliseconds: 80));
      api.pending.single.completeError(Exception('boom'));
      await Future<void>.delayed(Duration.zero);
      expect(c.error.value, contains('搜索失败'));
      expect(c.loading.value, isFalse);
      c.onClose();
    });
  });
}
