import 'package:flutter/material.dart';

/// 异步三态骨架（纯展示）。自己不持有任何状态，三态判断全由调用方传入——
/// 所以五个版本（setState/Provider/Bloc/GetX/Riverpod）都能复用它。
/// 类比 iOS：按 enum 切子视图的容器 View，判断逻辑留在 VC/ViewModel。
///
/// 约定：loading 优先于 error；"刷新时已有旧数据就别闪全屏 loading"
/// 由调用方控制，例如传 `loading: _loading && _items.isEmpty`。
class AsyncStateView extends StatelessWidget {
  const AsyncStateView({
    super.key,
    required this.loading,
    required this.error,
    required this.onRetry,
    required this.builder,
  });

  final bool loading;
  final String? error;
  final VoidCallback onRetry;
  final WidgetBuilder builder;

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(error!, textAlign: TextAlign.center),
            const SizedBox(height: 12),
            FilledButton(onPressed: onRetry, child: const Text('重试')),
          ],
        ),
      );
    }
    return builder(context);
  }
}
