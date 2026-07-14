import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:state_lab/shared/api/product_api.dart';
import 'package:state_lab/shared/models/product.dart';
import 'package:state_lab/versions/v2_bloc/state/search_bloc.dart';

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

void main() {
  group('SearchBloc', () {
    blocTest<SearchBloc, SearchState>(
      '防抖：400ms 内连续输入，只发最后一枪',
      build: () => SearchBloc(_RecordingApi()),
      act: (bloc) async {
        bloc.add(const SearchQueryChanged('p'));
        await Future<void>.delayed(const Duration(milliseconds: 150));
        bloc.add(const SearchQueryChanged('ph'));
        await Future<void>.delayed(const Duration(milliseconds: 150));
        bloc.add(const SearchQueryChanged('phone'));
      },
      wait: const Duration(milliseconds: 600),
      expect: () => [
        isA<SearchState>().having((s) => s.status, 'status', SearchStatus.loading),
        isA<SearchState>()
            .having((s) => s.status, 'status', SearchStatus.success)
            .having((s) => s.results.length, 'len', 1),
      ],
    );

    test('防抖 verify：只有最后一个词发出去', () async {
      final api = _RecordingApi();
      final bloc = SearchBloc(api);
      bloc.add(const SearchQueryChanged('p'));
      await Future<void>.delayed(const Duration(milliseconds: 150));
      bloc.add(const SearchQueryChanged('ph'));
      await Future<void>.delayed(const Duration(milliseconds: 150));
      bloc.add(const SearchQueryChanged('phone'));
      await Future<void>.delayed(const Duration(milliseconds: 600));
      expect(api.queries, ['phone']);
      await bloc.close();
    });

    blocTest<SearchBloc, SearchState>(
      '空查询：清空结果、不发请求',
      build: () => SearchBloc(_RecordingApi()),
      act: (bloc) => bloc.add(const SearchQueryChanged('   ')),
      wait: const Duration(milliseconds: 600),
      expect: () => [
        isA<SearchState>()
            .having((s) => s.results, 'results', isEmpty)
            .having((s) => s.error, 'error', isNull)
            .having((s) => s.status, 'status', SearchStatus.initial),
      ],
    );

    test('慢请求过期丢弃：restartable 掐掉旧处理器', () async {
      final api = _CompleterApi();
      final bloc = SearchBloc(api);
      final seen = <SearchState>[];
      final sub = bloc.stream.listen(seen.add);

      bloc.add(const SearchQueryChanged('ph'));
      await Future<void>.delayed(const Duration(milliseconds: 450)); // 第一枪已发，挂起
      bloc.add(const SearchQueryChanged('phone'));
      await Future<void>.delayed(const Duration(milliseconds: 450)); // 第二枪已发，挂起
      expect(api.pending.length, 2);

      api.pending[1].complete(const [_p2]); // 新请求先回
      await Future<void>.delayed(Duration.zero);
      expect(bloc.state.results.single.id, 2);

      api.pending[0].complete(const [_p1]); // 旧请求慢吞吞回来
      await Future<void>.delayed(Duration.zero);
      expect(bloc.state.results.single.id, 2); // 仍是新结果：旧处理器已被 restartable 掐死

      await sub.cancel();
      await bloc.close();
    });

    test('请求失败：error 落地', () async {
      final api = _CompleterApi();
      final bloc = SearchBloc(api);
      bloc.add(const SearchQueryChanged('phone'));
      await Future<void>.delayed(const Duration(milliseconds: 450));
      api.pending.single.completeError(Exception('boom'));
      await Future<void>.delayed(Duration.zero);
      expect(bloc.state.status, SearchStatus.failure);
      expect(bloc.state.error, contains('搜索失败'));
      await bloc.close();
    });
  });
}
