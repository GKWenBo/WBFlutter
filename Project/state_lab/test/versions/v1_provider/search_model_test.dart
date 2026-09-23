import 'dart:async';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:state_lab/shared/api/product_api.dart';
import 'package:state_lab/shared/models/product.dart';
import 'package:state_lab/versions/v1_provider/state/search_model.dart';

const _p1 = Product(id: 1, title: 'phone A', description: 'a', price: 1,
    thumbnail: 'x', rating: 4);
const _p2 = Product(id: 2, title: 'phone B', description: 'b', price: 2,
    thumbnail: 'x', rating: 4);

/// 记录每次搜索词的假 API。
class _RecordingApi implements ProductApi {
  final queries = <String>[];

  @override
  Future<List<Product>> searchProducts(String query) async {
    queries.add(query);
    return const [_p1];
  }

  @override
  Future<ProductPage> fetchProducts({
    required int skip,
    int limit = ProductApi.pageSize,
  }) =>
      throw UnimplementedError();
}

/// 请求挂起、由测试手动完成的假 API——模拟"慢请求"。
class _CompleterApi implements ProductApi {
  final pending = <Completer<List<Product>>>[];

  @override
  Future<List<Product>> searchProducts(String query) {
    final completer = Completer<List<Product>>();
    pending.add(completer);
    return completer.future;
  }

  @override
  Future<ProductPage> fetchProducts({
    required int skip,
    int limit = ProductApi.pageSize,
  }) =>
      throw UnimplementedError();
}

void main() {
  group('SearchModel', () {
    test('防抖：400ms 内连续输入，只发最后一枪', () {
      fakeAsync((async) {
        final api = _RecordingApi();
        final model = SearchModel(api);
        model.onQueryChanged('p');
        async.elapse(const Duration(milliseconds: 200));
        model.onQueryChanged('ph');
        async.elapse(const Duration(milliseconds: 200));
        model.onQueryChanged('phone');
        async.elapse(const Duration(milliseconds: 400));
        async.flushMicrotasks();
        expect(api.queries, ['phone']); // 前两枪被防抖掐灭
        expect(model.results.length, 1);
        expect(model.loading, isFalse);
      });
    });

    test('空查询：清空结果、不发请求', () {
      fakeAsync((async) {
        final api = _RecordingApi();
        final model = SearchModel(api);
        model.onQueryChanged('  ');
        async.elapse(const Duration(milliseconds: 400));
        async.flushMicrotasks();
        expect(api.queries, isEmpty);
        expect(model.results, isEmpty);
        expect(model.error, isNull);
      });
    });

    test('慢请求过期丢弃（手搓 switchToLatest 语义搬进模型）', () {
      fakeAsync((async) {
        final api = _CompleterApi();
        final model = SearchModel(api);
        model.onQueryChanged('ph');
        async.elapse(const Duration(milliseconds: 400)); // 第一枪已发，挂起
        model.onQueryChanged('phone');
        async.elapse(const Duration(milliseconds: 400)); // 第二枪已发，挂起
        expect(api.pending.length, 2);

        api.pending[1].complete(const [_p2]); // 新请求先回
        async.flushMicrotasks();
        expect(model.results.single.id, 2);

        api.pending[0].complete(const [_p1]); // 旧请求慢吞吞回来
        async.flushMicrotasks();
        expect(model.results.single.id, 2); // 仍是新结果：过期响应被丢
      });
    });

    test('请求失败：error 落地', () {
      fakeAsync((async) {
        final api = _CompleterApi();
        final model = SearchModel(api);
        model.onQueryChanged('phone');
        async.elapse(const Duration(milliseconds: 400));
        api.pending.single.completeError(Exception('boom'));
        async.flushMicrotasks();
        expect(model.error, contains('搜索失败'));
        expect(model.loading, isFalse);
      });
    });
  });
}
