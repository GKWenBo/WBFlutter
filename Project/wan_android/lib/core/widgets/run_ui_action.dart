import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../error/error_messages.dart';

/// 等待业务保存结果再反馈，≈ 在 iOS completion 中提示成功/失败。
Future<bool> runUiAction(
  BuildContext context,
  Future<void> Function() action, {
  String? successMessage,
}) async {
  try {
    await action();
    if (context.mounted && successMessage != null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(successMessage)));
    }
    return true;
  } catch (error) {
    if (context.mounted) {
      // M12：不再 '$error' 直出（那是开发者的中文诊断信息），按错误类型翻译成当前语言。
      final l10n = AppLocalizations.of(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.actionFailed(l10n.describeError(error)))),
      );
    }
    return false;
  }
}
