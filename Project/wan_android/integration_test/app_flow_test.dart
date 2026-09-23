// M11 教学重点：integration_test = Flutter 版端到端测试。
//
// iOS 对照：≈ XCUITest——启动"整个 App"，真实走导航、点真实控件、验证跨页面的结果。
//
// 和 test/ 下的 widget 测试有三点关键区别：
//   1. 放在**独立的 integration_test/ 目录**，用 `flutter test integration_test/` 跑；
//      也能用 `flutter drive` 跑到**真机/模拟器**上（widget 测试只在内存里 headless 跑）。
//   2. 第一行必须 `IntegrationTestWidgetsFlutterBinding.ensureInitialized()`——
//      换成能在真实设备上驱动的 binding（widget 测试用的是 AutomatedTestWidgetsFlutterBinding）。
//   3. 启动的是**真正的 WanShopApp**（含 go_router 全套路由），只把最外层的
//      "数据来源"换成 mock，其余全是生产代码——所以能验证"路由 + Provider + UI"串起来是否真的通。
//
// 何时该写 integration_test（测试金字塔顶层，少而精）：
//   验证"一条核心用户旅程真的能走通"，比如下单主流程、登录主流程。
//   单个页面/单个函数的细节留给下层的 widget/unit 测试（多而快）。

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wan_android/app/app.dart';
import 'package:wan_android/core/storage/auth_storage.dart';
import 'package:wan_android/features/auth/presentation/providers/auth_providers.dart';
import 'package:wan_android/features/products/data/product_list_response.dart';
import 'package:wan_android/features/products/data/products_repository.dart';
import 'package:wan_android/features/products/domain/product.dart';
import 'package:wan_android/features/products/presentation/providers/products_providers.dart';

class MockProductsRepository extends Mock implements ProductsRepository {}

/// 假存储：端到端测试不碰真实 Keychain，也保持"未登录"态。
class _FakeAuthStorage extends AuthStorage {
  @override
  Future<String?> readAccessToken() async => null;
}

const _product = Product(
  id: 1,
  title: '端到端测试商品',
  description: '一段描述',
  category: 'test',
  price: 199,
  discountPercentage: 10,
  rating: 4.8,
  stock: 20,
  thumbnail: 'http://x/1.png',
  images: [],
  tags: null,
);

void main() {
  // 必须的第一步：换成 integration 版 binding。
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('主流程：首页看到商品 → 点进详情 → 加入购物车成功', (tester) async {
    final repo = MockProductsRepository();
    // 首页列表、详情、分类三处数据来源都打桩（分类 Tab 会被 shell 一起构建）。
    when(
      () => repo.fetchProducts(limit: any(named: 'limit'), skip: any(named: 'skip')),
    ).thenAnswer(
      (_) async => const ProductListResponse(
        products: [_product],
        total: 1,
        skip: 0,
        limit: 20,
      ),
    );
    when(() => repo.fetchProduct(any())).thenAnswer((_) async => _product);
    when(() => repo.fetchCategories()).thenAnswer((_) async => []);

    // 网络图片在测试里拉不到真实字节，禁用缓存管理器的重试噪音（渲染占位即可，不影响断言）。
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          productsRepositoryProvider.overrideWithValue(repo),
          authStorageProvider.overrideWithValue(_FakeAuthStorage()),
        ],
        child: const WanShopApp(),
      ),
    );
    await tester.pumpAndSettle();

    // 1) 首页应渲染出商品标题。
    expect(find.text('端到端测试商品'), findsOneWidget);

    // 2) 点商品卡片 → go_router push 到 /product/1 详情页。
    await tester.tap(find.text('端到端测试商品'));
    await tester.pumpAndSettle();

    // 详情页出现"加入购物车"底部栏，证明路由确实跳过来了。
    expect(find.text('加入购物车'), findsOneWidget);

    // 3) 点"加入购物车" → 弹出确认 SnackBar，证明加购状态真的写进去了。
    await tester.tap(find.text('加入购物车'));
    await tester.pump(); // 让 SnackBar 出现一帧
    expect(find.textContaining('已加入购物车'), findsOneWidget);

    // 清理：让 CachedNetworkImage 的后台任务结束，避免测试收尾时有残留计时器。
    await tester.pumpAndSettle();
    await CachedNetworkImage.evictFromCache('http://x/1.png');
  });
}
