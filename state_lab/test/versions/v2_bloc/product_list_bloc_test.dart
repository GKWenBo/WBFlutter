import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:state_lab/shared/api/product_api.dart';
import 'package:state_lab/shared/models/product.dart';
import 'package:state_lab/versions/v2_bloc/state/product_list_bloc.dart';

const _p1 = Product(id: 1, title: 'A', description: 'a', price: 1, thumbnail: 'x', rating: 4);
const _p2 = Product(id: 2, title: 'B', description: 'b', price: 2, thumbnail: 'x', rating: 4);
const _p3 = Product(id: 3, title: 'C', description: 'c', price: 3, thumbnail: 'x', rating: 4);

/// 假 API：3 条数据、每页 2 条；可指定"下一次调用抛错"。
class _PagedFakeApi implements ProductApi {
  bool failNext = false;
  int fetchCalls = 0;

  @override
  Future<ProductPage> fetchProducts({
    required int skip,
    int limit = ProductApi.pageSize,
  }) async {
    fetchCalls++;
    if (failNext) {
      failNext = false;
      throw Exception('网络挂了');
    }
    const all = [_p1, _p2, _p3];
    final slice = all.skip(skip).take(2).toList();
    return ProductPage(products: slice, total: all.length, skip: skip, limit: limit);
  }

  @override
  Future<List<Product>> searchProducts(String query) => throw UnimplementedError();
}

void main() {
  group('ProductListBloc', () {
    blocTest<ProductListBloc, ProductListState>(
      'Started：loading → success，落地第一页',
      build: () => ProductListBloc(_PagedFakeApi()),
      act: (bloc) => bloc.add(ProductListStarted()),
      expect: () => [
        isA<ProductListState>().having((s) => s.status, 'status', ListStatus.loading),
        isA<ProductListState>()
            .having((s) => s.status, 'status', ListStatus.success)
            .having((s) => s.items.length, 'len', 2)
            .having((s) => s.hasMore, 'hasMore', true)
            .having((s) => s.error, 'error', isNull),
      ],
    );

    blocTest<ProductListBloc, ProductListState>(
      'LoadMore：翻页追加，到底后 hasMore=false',
      build: () => ProductListBloc(_PagedFakeApi()),
      act: (bloc) async {
        bloc.add(ProductListStarted());
        await bloc.stream.firstWhere((s) => s.status == ListStatus.success);
        bloc.add(ProductListLoadMore());
      },
      skip: 2, // 跳过 Started 的 loading/success
      expect: () => [
        isA<ProductListState>().having((s) => s.loadingMore, 'loadingMore', true),
        isA<ProductListState>()
            .having((s) => s.items.length, 'len', 3)
            .having((s) => s.hasMore, 'hasMore', false)
            .having((s) => s.loadingMore, 'loadingMore', false),
      ],
    );

    blocTest<ProductListBloc, ProductListState>(
      'Started 失败：落 failure 态',
      build: () => ProductListBloc(_PagedFakeApi()..failNext = true),
      act: (bloc) => bloc.add(ProductListStarted()),
      expect: () => [
        isA<ProductListState>().having((s) => s.status, 'status', ListStatus.loading),
        isA<ProductListState>()
            .having((s) => s.status, 'status', ListStatus.failure)
            .having((s) => s.error, 'error', contains('加载失败'))
            .having((s) => s.items, 'items', isEmpty),
      ],
    );

    blocTest<ProductListBloc, ProductListState>(
      'LoadMore 失败不打断已有列表（v0/v1 静默语义原样保留）',
      build: () => ProductListBloc(_PagedFakeApi()),
      act: (bloc) async {
        final api = bloc.api as _PagedFakeApi;
        bloc.add(ProductListStarted());
        await bloc.stream.firstWhere((s) => s.status == ListStatus.success);
        api.failNext = true;
        bloc.add(ProductListLoadMore());
      },
      skip: 2,
      expect: () => [
        isA<ProductListState>().having((s) => s.loadingMore, 'loadingMore', true),
        isA<ProductListState>()
            .having((s) => s.items.length, 'len', 2) // 旧数据还在
            .having((s) => s.hasMore, 'hasMore', true) // 还能再试
            .having((s) => s.loadingMore, 'loadingMore', false),
      ],
    );
  });
}
