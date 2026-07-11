import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:state_lab/shared/api/product_api.dart';

class MockDio extends Mock implements Dio {}

void main() {
  late MockDio dio;
  late ProductApi api;

  final pageJson = <String, dynamic>{
    'products': [
      {
        'id': 1, 'title': 'iPhone', 'description': 'd', 'price': 999.0,
        'thumbnail': 'x', 'rating': 4.5, 'brand': 'Apple',
      },
      {
        'id': 2, 'title': 'Pencil', 'description': 'd', 'price': 5,
        'thumbnail': 'x', 'rating': 4.0,
      },
    ],
    'total': 30,
    'skip': 0,
    'limit': 20,
  };

  setUp(() {
    dio = MockDio();
    api = ProductApi(dio);
    when(() => dio.get<dynamic>(any(), queryParameters: any(named: 'queryParameters')))
        .thenAnswer((_) async => Response<dynamic>(
              data: pageJson,
              requestOptions: RequestOptions(path: '/products'),
            ));
  });

  test('fetchProducts：路径 /products，limit/skip 参数正确，返回解析后的一页', () async {
    final page = await api.fetchProducts(skip: 0);

    expect(page.products.length, 2);
    expect(page.products.first.title, 'iPhone');
    expect(page.hasMore, isTrue);

    final captured = verify(() => dio.get<dynamic>(
          captureAny(),
          queryParameters: captureAny(named: 'queryParameters'),
        )).captured;
    expect(captured[0], '/products');
    expect(captured[1], {'limit': 20, 'skip': 0});
  });

  test('searchProducts：路径 /products/search，q 参数正确', () async {
    final results = await api.searchProducts('phone');

    expect(results.length, 2);
    final captured = verify(() => dio.get<dynamic>(
          captureAny(),
          queryParameters: captureAny(named: 'queryParameters'),
        )).captured;
    expect(captured[0], '/products/search');
    expect(captured[1], {'q': 'phone'});
  });
}
