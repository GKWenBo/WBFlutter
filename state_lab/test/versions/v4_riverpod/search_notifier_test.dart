import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:state_lab/shared/api/product_api.dart';
import 'package:state_lab/shared/models/product.dart';
import 'package:state_lab/versions/v4_riverpod/state/api_provider.dart';
import 'package:state_lab/versions/v4_riverpod/state/search_notifier.dart';

const _p1 = Product(id: 1, title: 'phone A', description: 'a', price: 1, thumbnail: 'x', rating: 4);
const _p2 = Product(id: 2, title: 'phone B', description: 'b', price: 2, thumbnail: 'x', rating: 4);

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

/// 防抖时长走 provider —— 测试 override 成 30ms 提速（riverpod 风格的
/// 可配置性：连 Duration 都是依赖，注入口子和 api 一模一样）。
ProviderContainer _make(ProductApi api) {
  final container = ProviderContainer(overrides: [
    productApiProvider.overrideWithValue(api),
    searchDebounceProvider.overrideWithValue(const Duration(milliseconds: 30)),
  ]);
  container.listen(searchProvider, (_, _) {}); // autoDispose 保活
  return container;
}

void main() {
  group('SearchNotifier', () {
    test('防抖：静默期内连续输入，只发最后一枪', () async {
      final api = _RecordingApi();
      final container = _make(api);
      addTearDown(container.dispose);
      final notifier = container.read(searchProvider.notifier);
      notifier.onQueryChanged('p');
      await Future<void>.delayed(const Duration(milliseconds: 10));
      notifier.onQueryChanged('ph');
      await Future<void>.delayed(const Duration(milliseconds: 10));
      notifier.onQueryChanged('phone');
      await Future<void>.delayed(const Duration(milliseconds: 80));
      expect(api.queries, ['phone']);
      expect(container.read(searchProvider).results.length, 1);
      expect(container.read(searchProvider).status, SearchStatus.success);
    });

    test('空查询：清空结果、不发请求', () async {
      final api = _RecordingApi();
      final container = _make(api);
      addTearDown(container.dispose);
      container.read(searchProvider.notifier).onQueryChanged('   ');
      await Future<void>.delayed(const Duration(milliseconds: 80));
      expect(api.queries, isEmpty);
      expect(container.read(searchProvider).status, SearchStatus.initial);
    });

    test('慢请求过期丢弃：手写序号（riverpod 无内建 switchMap，同 v1/v3）', () async {
      final api = _CompleterApi();
      final container = _make(api);
      addTearDown(container.dispose);
      final notifier = container.read(searchProvider.notifier);

      notifier.onQueryChanged('ph');
      await Future<void>.delayed(const Duration(milliseconds: 50));
      notifier.onQueryChanged('phone');
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(api.pending.length, 2);

      api.pending[1].complete(const [_p2]); // 新请求先回
      await Future<void>.delayed(Duration.zero);
      expect(container.read(searchProvider).results.single.id, 2);

      api.pending[0].complete(const [_p1]); // 旧请求慢吞吞回来
      await Future<void>.delayed(Duration.zero);
      expect(container.read(searchProvider).results.single.id, 2); // 过期被扔
    });

    test('请求失败：failure 落地', () async {
      final api = _CompleterApi();
      final container = _make(api);
      addTearDown(container.dispose);
      container.read(searchProvider.notifier).onQueryChanged('phone');
      await Future<void>.delayed(const Duration(milliseconds: 50));
      api.pending.single.completeError(Exception('boom'));
      await Future<void>.delayed(Duration.zero);
      expect(container.read(searchProvider).status, SearchStatus.failure);
      expect(container.read(searchProvider).error, contains('搜索失败'));
    });
  });
}
