import 'package:dio/dio.dart';

import '../models/product.dart';

/// 商品接口封装（≈ 一个只管发请求 + 解析的 Service 类，无状态）。
/// 五个版本共用同一个 ProductApi——网络层与状态管理无关，是共享底座。
class ProductApi {
  ProductApi(this._dio);

  final Dio _dio;

  /// 每页条数（设计文档冻结值）。
  static const int pageSize = 20;

  /// 取一页商品。skip 是偏移量（DummyJSON 风格分页，≈ offset）。
  Future<ProductPage> fetchProducts({
    required int skip,
    int limit = pageSize,
  }) async {
    final res = await _dio.get<dynamic>(
      '/products',
      queryParameters: {'limit': limit, 'skip': skip},
    );
    return ProductPage.fromJson(res.data as Map<String, dynamic>);
  }

  /// 按关键词搜索（服务端搜索，不分页——课程场景够用，YAGNI）。
  Future<List<Product>> searchProducts(String query) async {
    final res = await _dio.get<dynamic>(
      '/products/search',
      queryParameters: {'q': query},
    );
    return ProductPage.fromJson(res.data as Map<String, dynamic>).products;
  }
}
