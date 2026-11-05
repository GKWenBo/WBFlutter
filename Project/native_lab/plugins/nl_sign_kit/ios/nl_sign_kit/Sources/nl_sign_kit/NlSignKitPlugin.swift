import Flutter
// 导入 SwiftPM 的 C target（module map 由 include/nl_sign_kit_c.h 生成）。
import nl_sign_kit_c

/// L10 FFI 插件的 iOS 入口。
///
/// ★ 这个插件不注册任何 MethodChannel —— 它就是纯 FFI。
/// 那为什么还要实现 FlutterPlugin？因为 iOS 的 C 代码是【静态链接】进 App 的：
/// 如果没有任何 Swift/ObjC 代码引用 nl_sign_kit.c 里的符号，链接器会把它当
/// 死代码裁掉，Dart 侧 DynamicLibrary.process() 就 dlsym 不到。
/// 在 register 里调用一下 nl_sign_kit_warmup()，就把这个目标文件“拽”进来了。
public class NlSignKitPlugin: NSObject, FlutterPlugin {
    public static func register(with registrar: FlutterPluginRegistrar) {
        // 返回值用 _ = 吞掉；warmup 内部会写 volatile 全局变量，
        // 不会被优化器删掉。
        _ = nl_sign_kit_warmup()
    }
}
