import 'package:flutter/widgets.dart';

/// 手写迷你 Provider：InheritedWidget + Listenable 的胶水（约 40 行核心逻辑）。
/// 这就是 framework 里 InheritedNotifier 的实现结构——写完可以打开
/// flutter/lib/src/widgets/inherited_notifier.dart 逐行对照。
/// 类比 iOS：.environmentObject(model) 挂树 + @EnvironmentObject 取用自动刷新。
class MiniProvider<T extends Listenable> extends InheritedWidget {
  const MiniProvider({super.key, required this.notifier, required super.child});

  final T notifier;

  /// 取值 + 注册依赖（≈ @EnvironmentObject / 后面 Provider 的 context.watch）。
  /// dependOn... 做了两件事：O(1) 查表拿到祖先 provider + 把调用方登记进
  /// 它的依赖名单。notifier 每次开火，名单上的 Element 挨个重建。
  static T of<T extends Listenable>(BuildContext context) {
    final provider =
        context.dependOnInheritedWidgetOfExactType<MiniProvider<T>>();
    assert(provider != null, '往上找不到 MiniProvider<$T>：这条路由包了吗？');
    return provider!.notifier;
  }

  /// 只取值、不登记依赖（≈ 后面 Provider 的 context.read）。
  /// 事件回调里用它——回调不是 build，不需要"数据变了重跑一遍"。
  static T read<T extends Listenable>(BuildContext context) {
    final provider = context.getInheritedWidgetOfExactType<MiniProvider<T>>();
    assert(provider != null, '往上找不到 MiniProvider<$T>：这条路由包了吗？');
    return provider!.notifier;
  }

  /// 只在 widget 实例被替换时走到（父级重建/热重载传了新 notifier）。
  /// 日常 notifyListeners 的刷新不走这里——走下面 Element 的订阅。
  @override
  bool updateShouldNotify(MiniProvider<T> oldWidget) =>
      notifier != oldWidget.notifier;

  @override
  InheritedElement createElement() => _MiniProviderElement<T>(this);
}

/// 自定义 Element：真正的"通知引擎"。
/// InheritedWidget 天生只会在**自己被替换**时通知依赖者；想要
/// "notifier 开火 → 依赖者重建"，必须有人订阅 notifier——就是这个 Element。
class _MiniProviderElement<T extends Listenable> extends InheritedElement {
  _MiniProviderElement(MiniProvider<T> widget) : super(widget) {
    widget.notifier.addListener(_handleUpdate); // 上树即订阅
  }

  bool _dirty = false;

  @override
  void update(MiniProvider<T> newWidget) {
    // 父级重建换了 notifier 实例：退订旧的、订上新的。
    final oldNotifier = (widget as MiniProvider<T>).notifier;
    if (oldNotifier != newWidget.notifier) {
      oldNotifier.removeListener(_handleUpdate);
      newWidget.notifier.addListener(_handleUpdate);
    }
    super.update(newWidget);
  }

  void _handleUpdate() {
    _dirty = true;
    markNeedsBuild(); // 排队到下一帧：build 里把消息扩散给依赖者
  }

  @override
  Widget build() {
    if (_dirty) {
      notifyClients(widget as MiniProvider<T>); // 挨个喊依赖者 didChangeDependencies
      _dirty = false;
    }
    return super.build();
  }

  @override
  void unmount() {
    (widget as MiniProvider<T>).notifier.removeListener(_handleUpdate); // 防泄漏
    super.unmount();
  }
}
