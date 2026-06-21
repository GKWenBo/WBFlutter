import 'package:dio/dio.dart';

import '../../../core/error/failure.dart';
import '../../../core/network/dio_client.dart';
import 'product_list_response.dart';
import '../domain/product.dart';

/// 商品数据仓库：UI 只调它的方法，不直接碰 dio。
/// ≈ 你 iOS 里的 ProductService / Repository——隔离网络细节，便于替换数据源与单元测试。
class ProductsRepository {
  final Dio _dio;

  // 默认用全局单例的 dio；测试时可注入一个 mock dio（依赖注入）。
  ProductsRepository({Dio? dio}) : _dio = dio ?? DioClient.instance.dio;

  /// 拉商品列表（带分页）。
  /// [limit]=每页数量，[skip]=跳过多少条（= 页码 × limit）。
  Future<ProductListResponse> fetchProducts({
    int limit = 20,
    int skip = 0,
  }) async {
    try {
      final res = await _dio.get(
        '/products',
        queryParameters: {'limit': limit, 'skip': skip},
      );
      // dio 默认已把响应体解析成 Map，直接喂给 M2 写好的 fromJson。
      return ProductListResponse.fromJson(res.data as Map<String, dynamic>);
    } on DioException catch (e) {
      // 网络/服务器类错误 → 翻译成应用层异常（在拦截器里已打过日志）。
      throw AppException.fromDio(e);
    } catch (e) {
      // 解析等其它错误。
      throw ParseException('数据解析失败：$e');
    }
  }

  /// 拉单个商品详情。
  /// [id]=商品 id，拼进路径 `/products/{id}`（≈ RESTful 的资源定位）。
  Future<Product> fetchProduct(int id) async {
    try {
      final res = await _dio.get('/products/$id');
      // 这里返回的是单个商品对象，所以用 Product.fromJson，而不是列表的 ProductListResponse。
      return Product.fromJson(res.data as Map<String, dynamic>);
    } on DioException catch (e) {
      // 网络/服务器类错误 → 翻译成应用层异常（与 fetchProducts 保持一致）。
      throw AppException.fromDio(e);
    } catch (e) {
      // 解析等其它错误。
      throw ParseException('数据解析失败：$e');
    }
  }
}
