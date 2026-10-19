import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';

/// 通用错误占位：图标 + 文案 +（可选）重试按钮。
/// 多个页面共用，避免到处重复写错误 UI（开始消除之前提到的"坏味道"）。
class ErrorView extends StatelessWidget {
  final String message;
  final VoidCallback? onRetry;

  const ErrorView({super.key, required this.message, this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cloud_off, size: 48, color: Colors.grey),
            const SizedBox(height: 12),
            Text(message, textAlign: TextAlign.center),
            if (onRetry != null) ...[
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: onRetry,
                // M12：按钮文案也来自 ARB——共享组件里的硬编码同样会漏翻。
                child: Text(AppLocalizations.of(context).retry),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
