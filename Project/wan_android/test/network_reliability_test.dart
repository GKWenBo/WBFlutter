import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wan_android/core/error/failure.dart';
import 'package:wan_android/core/network/auth_interceptor.dart';
import 'package:wan_android/core/network/dio_client.dart';
import 'package:wan_android/core/storage/auth_storage.dart';
import 'package:wan_android/features/categories/data/categories_repository.dart';
import 'package:wan_android/features/products/data/products_dependencies.dart';
import 'package:wan_android/features/products/data/products_repository.dart';

class BrokenAuthStorage extends AuthStorage {
  @override
  Future<String?> readAccessToken() async => throw StateError('安全存储不可用');
}

class TokenStorage extends AuthStorage {
  @override
  Future<String?> readAccessToken() async => 'injected-token';
}

class RecordingAdapter implements HttpClientAdapter {
  RecordingAdapter(this.body, {this.status = 200});
  final String body;
  final int status;
  RequestOptions? request;
  bool closed = false;
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    request = options;
    return ResponseBody.fromString(
      body,
      status,
      headers: {
        Headers.contentTypeHeader: ['application/json'],
      },
    );
  }

  @override
  void close({bool force = false}) {
    closed = true;
  }
}

void main() {
  test('安全存储失败明确拒绝请求，不悬挂', () async {
    final dio = Dio()..interceptors.add(AuthInterceptor(BrokenAuthStorage()));
    addTearDown(() => dio.close(force: true));
    await expectLater(
      dio
          .get('https://example.invalid')
          .timeout(const Duration(milliseconds: 200)),
      throwsA(isA<DioException>()),
    );
  });
  test('容器注入的安全存储供拦截器使用，销毁时关闭客户端', () async {
    final container = ProviderContainer(
      overrides: [authStorageProvider.overrideWithValue(TokenStorage())],
    );
    final adapter = RecordingAdapter(
      '{"products":[],"total":0,"skip":0,"limit":20}',
    );
    container.read(dioProvider).httpClientAdapter = adapter;
    final page = await container
        .read(productsRepositoryProvider)
        .fetchProducts();
    expect(page.products, isEmpty);
    expect(adapter.request!.headers['Authorization'], 'Bearer injected-token');
    container.dispose();
    expect(adapter.closed, isTrue);
  });
  test('服务器错误与响应结构错误分开映射', () async {
    final dio = Dio();
    addTearDown(() => dio.close(force: true));
    final repository = ProductsRepository(dio: dio);
    dio.httpClientAdapter = RecordingAdapter('{}', status: 503);
    await expectLater(
      repository.fetchProducts(),
      throwsA(isA<ServerException>().having((e) => e.code, 'status', 503)),
    );
    dio.httpClientAdapter = RecordingAdapter('[]');
    await expectLater(
      repository.fetchProducts(),
      throwsA(isA<ParseException>()),
    );
  });
  test('分类请求由分类仓库解析', () async {
    final dio = Dio()
      ..httpClientAdapter = RecordingAdapter(
        '[{"slug":"beauty","name":"Beauty","url":"https://dummyjson.com/products/category/beauty"}]',
      );
    addTearDown(() => dio.close(force: true));
    final categories = await CategoriesRepository(dio: dio).fetchCategories();
    expect(categories.single.slug, 'beauty');
  });
  test('传输层 JSON 文本损坏也映射为解析错误', () async {
    final dio = Dio()..httpClientAdapter = RecordingAdapter('{broken');
    addTearDown(() => dio.close(force: true));
    await expectLater(
      ProductsRepository(dio: dio).fetchProducts(),
      throwsA(isA<ParseException>()),
    );
  });
}
