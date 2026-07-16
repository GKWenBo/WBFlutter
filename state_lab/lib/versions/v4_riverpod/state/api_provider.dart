import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/api/product_api.dart';

/// 服务 DI 的 riverpod 姿势：provider 是**顶层 final 常量**——引用即存在，
/// 编译期就保证"这个依赖一定有"（对照 GetX 的 Get.find 运行时查表、
/// Provider 的 ProviderNotFoundException 运行时炸）。
/// 真实实例在 V4ShopRoot 的 ProviderScope 里 override 注入（生产 Dio /
/// 测试 Fake 同一个口子），所以这里的默认实现直接抛——谁忘了 override
/// 谁第一时间知道。
final productApiProvider = Provider<ProductApi>(
  (ref) => throw UnimplementedError('productApiProvider 必须在 ProviderScope override'),
);
