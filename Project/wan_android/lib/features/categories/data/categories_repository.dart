import 'package:dio/dio.dart';

import '../../../core/network/request_json.dart';
import '../domain/category.dart';

/// M6 分类列表属于分类模块，商品仓库不反向依赖分类模型。
class CategoriesRepository {
  final Dio _dio;
  // Dart 3.12 私有字段命名初始化参数，对外仍通过 dio: 注入。
  CategoriesRepository({required this._dio});
  Future<List<Category>> fetchCategories() => requestJson(
    () => _dio.get('/products/categories'),
    (data) => (data as List<dynamic>)
        .map((item) => Category.fromJson(item as Map<String, dynamic>))
        .toList(growable: false),
  );
}
