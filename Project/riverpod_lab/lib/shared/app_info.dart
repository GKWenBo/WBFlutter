import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'app_info.g.dart';

/// 应用版本号。
///
/// 用 provider 而不是全局常量，是为了演示"只读依赖"的注入方式：
/// 测试或多环境里可以用 override 换成别的值，而不用改调用方。
@riverpod
String appVersion(Ref ref) => '1.0.0';
