import 'package:dio/dio.dart';

import '../../../core/network/request_json.dart';
import '../domain/product.dart';
import 'product_list_response.dart';

/// M3 商品仓库：显式注入 Dio，UI 不接触传输与解码细节。
/// ≈ iOS Repository 构造时接收 URLSession，而不是暗中使用 shared。
class ProductsRepository {
  final Dio _dio;
  // Dart 3.12 私有字段命名初始化参数，对外仍通过 dio: 注入。
  ProductsRepository({required this._dio});

  Future<ProductListResponse> fetchProducts({int limit = 20, int skip = 0}) =>
      _fetchPage('/products', {'limit': limit, 'skip': skip});

  Future<Product> fetchProduct(int id) => requestJson(
    () => _dio.get('/products/$id'),
    (data) => Product.fromJson(data as Map<String, dynamic>),
  );

  Future<ProductListResponse> fetchByCategory(
    String slug, {
    int limit = 30,
    int skip = 0,
  }) => _fetchPage('/products/category/$slug', {'limit': limit, 'skip': skip});

  Future<ProductListResponse> searchProducts(
    String query, {
    int limit = 30,
    int skip = 0,
  }) => _fetchPage('/products/search', {
    'q': query,
    'limit': limit,
    'skip': skip,
  });

  Future<ProductListResponse> _fetchPage(
    String path,
    Map<String, dynamic> query,
  ) => requestJson(
    () => _dio.get(path, queryParameters: query),
    (data) => ProductListResponse.fromJson(data as Map<String, dynamic>),
  );
}
