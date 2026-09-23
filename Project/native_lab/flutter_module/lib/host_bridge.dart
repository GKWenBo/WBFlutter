import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// 模块的全局 Navigator 句柄。
/// ★ 为什么需要它：宿主要在【引擎已经跑起来之后】切换模块页面，
///   而此时手上没有任何 BuildContext——只能靠这个全局 key 拿到 NavigatorState。
final GlobalKey<NavigatorState> moduleNavigatorKey = GlobalKey<NavigatorState>();

/// 宿主桥（Flutter 模块侧）。
/// ★ L1–L7 里 Flutter 是宿主、原生是"被调的一方"；add-to-app 反过来——
///   **原生 App 才是宿主**，Flutter 是寄居的模块。所以这条 channel 是双向的：
///   · Flutter → 原生：要 token、请宿主关页面（invokeMethod）
///   · 原生 → Flutter：问模块当前状态（setMethodCallHandler 接收）
class HostBridge {
  HostBridge._() {
    // 注册接收端：原生调过来时进这里（对照 L1 原生侧的 setMethodCallHandler，
    // 只是角色对调了——这次"被调"的是 Flutter）。
    _channel.setMethodCallHandler(_handleFromHost);
  }

  static final HostBridge instance = HostBridge._();

  /// 三端逐字符一致（Swift 侧同名）。
  static const MethodChannel _channel =
      MethodChannel('com.wenbo.add_to_app/host');

  /// 原生问"你现在是什么状态"时，用这个回调取答案。页面自己填。
  String Function()? onHostQuery;

  Future<Object?> _handleFromHost(MethodCall call) async {
    switch (call.method) {
      case 'getPageState':
        // 原生 → Flutter 的查询：把当前页状态回给宿主。
        return onHostQuery?.call() ?? '模块已启动（未设置状态提供者）';
      case 'setRoute':
        // ★ 热引擎的路由协调（L9 的坑）：
        //   引擎【已经在跑】时，setInitialRoute 是无效的——widget 树早按
        //   initialRoute 建好了，再设只是改了个没人读的值。
        //   所以宿主要换页，必须像这样通过通道驱动真正的 Navigator。
        final route = call.arguments as String? ?? '/';
        // pushNamedAndRemoveUntil：清空模块内的旧栈再进新页，
        // 避免宿主反复打开时 Flutter 侧堆一叠返回不掉的页面。
        moduleNavigatorKey.currentState
            ?.pushNamedAndRemoveUntil(route, (_) => false);
        return null;
      default:
        // 对照 L1 原生侧的 FlutterMethodNotImplemented：方法名对不上要明确报错，
        // 别静默返回 null 让宿主以为成功了。
        throw MissingPluginException('模块未实现方法：${call.method}');
    }
  }

  /// Flutter → 原生：向宿主要用户 token（企业真实场景：登录态在原生 App 手里）。
  Future<String> getUserToken() async {
    final token = await _channel.invokeMethod<String>('getUserToken');
    return token ?? '';
  }

  /// Flutter → 原生：请宿主关掉这个 Flutter 页。
  /// ★ 为什么不能自己 Navigator.pop？因为这个页是被原生 present 的，
  ///   它在 Flutter 路由栈里是【根页】，pop 掉只会剩黑屏——必须让宿主去 dismiss。
  Future<void> closePage() => _channel.invokeMethod('closePage');
}
