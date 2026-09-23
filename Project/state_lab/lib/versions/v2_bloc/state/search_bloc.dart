import 'package:bloc_concurrency/bloc_concurrency.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:stream_transform/stream_transform.dart';

import '../../../shared/api/product_api.dart';
import '../../../shared/models/product.dart';

/// 场景⑤：输入流处理。这是 Bloc 相对 S2 最亮的一课——v1 里靠手写
/// `Timer` 防抖 + 请求序号丢过期两坨逻辑，这里被一个 EventTransformer
/// 一锅端：debounce(去抖) + restartable(switchMap，新事件掐掉旧处理器)。
/// 事件流当一等公民处理，正是 Bloc≈Combine 单向数据流的精髓。

enum SearchStatus { initial, loading, success, failure }

sealed class SearchEvent {
  const SearchEvent();
}

class SearchQueryChanged extends SearchEvent {
  const SearchQueryChanged(this.query);
  final String query;
}

class SearchRetried extends SearchEvent {
  const SearchRetried();
}

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

/// debounce 先把连打的事件流去抖，restartable 再保证只有最新那个处理器
/// 活着——旧处理器被 switchMap 取消，它 await 回来时 emit 已是 no-op。
EventTransformer<E> _debounceRestartable<E>(Duration duration) {
  return (events, mapper) =>
      restartable<E>().call(events.debounce(duration), mapper);
}

class SearchBloc extends Bloc<SearchEvent, SearchState> {
  SearchBloc(this._api, {this.debounce = const Duration(milliseconds: 400)})
      : super(const SearchState()) {
    on<SearchQueryChanged>(
      _onQueryChanged,
      transformer: _debounceRestartable(debounce),
    );
    on<SearchRetried>((event, emit) => _search(state.query, emit));
  }

  final ProductApi _api;
  final Duration debounce;

  Future<void> _onQueryChanged(
    SearchQueryChanged event,
    Emitter<SearchState> emit,
  ) =>
      _search(event.query.trim(), emit);

  Future<void> _search(String query, Emitter<SearchState> emit) async {
    if (query.isEmpty) {
      emit(const SearchState()); // 回到 initial，清空
      return;
    }
    emit(SearchState(status: SearchStatus.loading, query: query));
    try {
      final results = await _api.searchProducts(query);
      emit(SearchState(
        status: SearchStatus.success,
        query: query,
        results: results,
      ));
    } catch (e) {
      emit(SearchState(
        status: SearchStatus.failure,
        query: query,
        error: '搜索失败：$e',
      ));
    }
  }
}
