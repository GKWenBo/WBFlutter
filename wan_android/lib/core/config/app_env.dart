/// M12 · 多环境（Flavor）编译期配置。
///
/// iOS 对照：≈ Xcode 的 Build Configuration + Scheme + .xcconfig，以及 `#if DEBUG`。
/// 你在 iOS 里用不同 Scheme 切 API 域名、Bundle Id、日志开关；这里用 Flutter 的
/// **编译期常量** `--dart-define` 做同一件事，但不动原生工程、纯 Dart 一层搞定。
///
/// 怎么跑：
///   flutter run                                   # 默认 dev
///   flutter run --dart-define=FLAVOR=staging      # 预发
///   flutter run --dart-define=FLAVOR=prod          # 生产
///   flutter build apk --dart-define=FLAVOR=prod    # 打包同理
///
/// 为什么用 `--dart-define` 而不是运行时读配置文件：
///   它是**编译期常量**（`String.fromEnvironment` 只认编译期传入），
///   会被 tree-shaking 优化，且不可能在运行时被篡改——适合"选环境"这种一次定死的开关。
library;

/// 三套环境。≈ 你 iOS 的 Debug / Staging / Release 三个 Scheme。
enum Flavor { dev, staging, prod }

/// 单套环境的配置项。用 const 构造，保证每套配置都是编译期常量。
class FlavorConfig {
  final Flavor flavor;

  /// App 标题（会显示在 MaterialApp.title / 任务切换器里）。
  final String appTitle;

  /// 后端域名。真实项目里 dev/staging/prod 各指一套；
  /// 本项目只有 DummyJSON 一个公开 API，所以三套先都指它——
  /// 教学重点是"这里能按环境切"，不是真的有三套后端。
  final String baseUrl;

  /// 是否打网络日志。生产环境关掉，避免刷屏 + 泄露请求细节。
  final bool enableLogging;

  /// 是否在右上角显示环境水印角标（dev/staging 显示，prod 不显示）。
  final bool showEnvBanner;

  const FlavorConfig({
    required this.flavor,
    required this.appTitle,
    required this.baseUrl,
    required this.enableLogging,
    required this.showEnvBanner,
  });
}

/// 把 flavor 映射成具体配置。抽成**纯函数**是为了能单测（不依赖编译期常量）。
FlavorConfig flavorConfigFor(Flavor flavor) => switch (flavor) {
  Flavor.dev => const FlavorConfig(
    flavor: Flavor.dev,
    appTitle: 'WanShop Dev',
    baseUrl: 'https://dummyjson.com',
    enableLogging: true,
    showEnvBanner: true,
  ),
  Flavor.staging => const FlavorConfig(
    flavor: Flavor.staging,
    appTitle: 'WanShop Staging',
    baseUrl: 'https://dummyjson.com',
    enableLogging: true,
    showEnvBanner: true,
  ),
  Flavor.prod => const FlavorConfig(
    flavor: Flavor.prod,
    appTitle: 'WanShop',
    baseUrl: 'https://dummyjson.com',
    enableLogging: false,
    showEnvBanner: false,
  ),
};

/// 把 `--dart-define=FLAVOR=xxx` 的原始字符串解析成 Flavor。
/// 大小写宽容、接受常见别名；**无法识别时兜底 dev**（本地开发最安全的默认，
/// 绝不会误当成 prod 去连生产库）。抽成纯函数同样是为了可单测。
Flavor parseFlavor(String raw) => switch (raw.trim().toLowerCase()) {
  'prod' || 'production' || 'release' => Flavor.prod,
  'staging' || 'stg' || 'stage' => Flavor.staging,
  _ => Flavor.dev,
};

/// 全局环境入口。App 任何地方 `AppEnv.current` 拿到当前环境配置。
class AppEnv {
  AppEnv._();

  /// 编译期读取 `--dart-define=FLAVOR=...`，没传时默认 'dev'。
  /// 注意：`String.fromEnvironment` 必须是 const 上下文，且只在**编译期**求值。
  static const String _rawFlavor = String.fromEnvironment(
    'FLAVOR',
    defaultValue: 'dev',
  );

  /// 当前环境配置。整个 App 启动后就定死，不会变。
  static final FlavorConfig current = flavorConfigFor(parseFlavor(_rawFlavor));
}
