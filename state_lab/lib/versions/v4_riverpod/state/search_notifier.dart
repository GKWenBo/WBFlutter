import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/models/product.dart';
import 'api_provider.dart';

enum SearchStatus { initial, loading, success, failure }

class SearchState extends Equatable {
  const SearchState({
    this.status = SearchStatus.initial,
    this.query = '',
    this.results = const [],
    this.error,
  });

  final SearchStatus status;
  final String query;
  final List<Product> results;
  final String? error;

  @override
  List<Object?> get props => [status, query, results, error];
}

/// 防抖时长走 provider（riverpod 风格：配置也是依赖）——测试 override
/// 成 30ms 提速，生产默认 400ms（设计文档冻结值）。
final searchDebounceProvider =
    Provider<Duration>((ref) => const Duration(milliseconds: 400));

/// 场景⑤：riverpod 没有内建的防抖/switchMap 件（它管"状态怎么共享"，
/// 不管"事件流怎么编排"）——Timer 防抖 + 序号丢过期两坨手写又回来了
/// （v1 同款；对照 v2 的 EventTransformer 一锅端，这是 Bloc 在输入流
/// 场景的独门优势，S5 §1.2 的结论在这里再次验证）。
/// riverpod 给的是收尾托管：ref.onDispose 挂 Timer 清理，autoDispose
/// 页面一走连人带 Timer 全没。
class SearchNotifier extends Notifier<SearchState> {
  Timer? _timer;
  int _seq = 0;

  @override
  SearchState build() {
    ref.onDispose(() => _timer?.cancel()); // 悬垂 Timer 的 riverpod 式疫苗
    return const SearchState();
  }

  void onQueryChanged(String text) {
    _timer?.cancel();
    _timer = Timer(ref.read(searchDebounceProvider), () => _search(text.trim()));
  }

  Future<void> retry() => _search(state.query);

  Future<void> _search(String query) async {
    if (query.isEmpty) {
      state = const SearchState();
      return;
    }
    final seq = ++_seq;
    state = SearchState(status: SearchStatus.loading, query: query);
    try {
      final results = await ref.read(productApiProvider).searchProducts(query);
      if (seq != _seq) return; // 过期响应，扔
      state = SearchState(
        status: SearchStatus.success,
        query: query,
        results: results,
      );
    } catch (e) {
      if (seq != _seq) return;
      state = SearchState(
        status: SearchStatus.failure,
        query: query,
        error: '搜索失败：$e',
      );
    }
  }
}

final searchProvider = NotifierProvider.autoDispose<SearchNotifier, SearchState>(
  SearchNotifier.new,
);
